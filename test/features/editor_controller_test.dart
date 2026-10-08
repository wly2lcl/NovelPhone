import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novelphone/data/db.dart';
import 'package:novelphone/data/repositories/chapter_repository.dart';
import 'package:novelphone/data/repositories/work_repository.dart';
import 'package:novelphone/features/editor/editor_controller.dart';

void main() {
  late AppDatabase db;
  late WorkRepository works;
  late ChapterRepository chapters;
  late int workId;
  late int chapterId;
  late EditorController controller;

  setUp(() async {
    db = AppDatabase.memory();
    works = WorkRepository(db);
    chapters = ChapterRepository(db);
    workId = await works.createWork(title: '长夜行');
    chapterId = await chapters.createChapter(workId: workId, title: '第一章');
    controller = EditorController(
      repository: chapters,
      workId: workId,
      chapterId: chapterId,
    );
  });

  tearDown(() async {
    controller.dispose();
    await db.close();
  });

  test('载入章节正文并恢复光标位置', () async {
    await chapters.saveChapter(
      chapterId: chapterId,
      title: '第一章',
      content: '两人对坐，谁也没有先开口。',
      cursorOffset: 4,
      scrollOffset: 120,
    );

    await controller.load();

    expect(controller.loaded, isTrue);
    expect(controller.title, '第一章');
    expect(controller.textController.text, '两人对坐，谁也没有先开口。');
    expect(controller.textController.selection.baseOffset, 4);
    expect(controller.initialScrollOffset, 120);
    expect(controller.chapterWords, 11);
    expect(controller.canUndo, isFalse);
    expect(controller.canRedo, isFalse);
  });

  test('载入超过正文长度的光标位置时收敛到结尾', () async {
    await chapters.saveChapter(chapterId: chapterId, title: '', content: '短句。');
    await chapters.saveCursorPosition(
        chapterId: chapterId, cursorOffset: 999, scrollOffset: 0);

    await controller.load();

    expect(controller.textController.selection.baseOffset, 3);
  });

  test('停止输入后自动保存并更新字数状态', () async {
    await controller.load();

    controller.textController.text = '雨下了一整夜，街道上没有人。';
    expect(controller.saveStatus, SaveStatus.saving);
    expect(controller.chapterWords, 12);

    await Future<void>.delayed(EditorController.autosaveDelay + const Duration(milliseconds: 300));

    expect(controller.saveStatus, SaveStatus.saved);
    expect(controller.lastSavedAt, isNotNull);
    final saved = await chapters.getChapter(chapterId);
    expect(saved!.content, '雨下了一整夜，街道上没有人。');
    expect(saved.wordCount, 12);
  });

  test('flush 落库正文与光标位置', () async {
    await controller.load();
    controller.textController.text = '两人对坐。';
    controller.textController.selection = TextSelection.collapsed(offset: 2);

    await controller.flush();

    final saved = await chapters.getChapter(chapterId);
    expect(saved!.content, '两人对坐。');
    expect(saved.cursorOffset, 2);
  });

  test('撤销与重做走编辑器自己的历史栈', () async {
    await controller.load();
    expect(controller.canUndo, isFalse);

    controller.textController.text = '后来他说了一句话。';
    controller.undo();

    expect(controller.textController.text, '');
    expect(controller.canUndo, isFalse);
    expect(controller.canRedo, isTrue);

    controller.redo();

    expect(controller.textController.text, '后来他说了一句话。');
    expect(controller.canRedo, isFalse);
    expect(controller.canUndo, isTrue);
  });

  test('新输入会清空重做栈', () async {
    await controller.load();
    controller.textController.text = '第一版';
    controller.undo();
    expect(controller.canRedo, isTrue);

    controller.textController.text = '第二版';
    controller.redo();

    expect(controller.textController.text, '第二版');
    expect(controller.canRedo, isFalse);
  });

  test('查找命中数与大小写选项', () async {
    await controller.load();
    controller.textController.text = 'Cat 和 cat 都是猫。';

    expect(controller.countMatches('cat'), 2);
    expect(controller.countMatches('cat', caseSensitive: true), 1);
    expect(controller.countMatches(''), 0);
    expect(controller.countMatches('狗'), 0);

    final matches = controller.findMatches('cat', caseSensitive: true);
    expect(matches.single.start, 6);
    expect(matches.single.end, 9);
  });

  test('替换光标本处命中与全部替换', () async {
    await controller.load();
    controller.textController.text = '猫猫狗狗猫';
    controller.textController.selection = TextSelection.collapsed(offset: 0);

    final replaced = controller.replaceNext('猫', '喵');

    expect(replaced, isTrue);
    expect(controller.textController.text, '喵猫狗狗猫');
    expect(controller.textController.selection.baseOffset, 1);

    final count = controller.replaceAll('猫', '喵');

    expect(count, 2);
    expect(controller.textController.text, '喵喵狗狗喵');
  });

  test('替换不存在的关键词返回 false', () async {
    await controller.load();
    controller.textController.text = '正文';

    expect(controller.replaceNext('缺', '补'), isFalse);
    expect(controller.replaceAll('缺', '补'), 0);
    expect(controller.textController.text, '正文');
  });

  test('段落上移与下移交换相邻行并跟随光标', () async {
    await controller.load();
    controller.textController.text = 'A\nB\nC';
    controller.textController.selection = TextSelection.collapsed(offset: 3);

    controller.moveParagraph(up: true);
    expect(controller.textController.text, 'B\nA\nC');
    expect(controller.textController.selection.baseOffset, 1);

    controller.moveParagraph(up: false);
    expect(controller.textController.text, 'A\nB\nC');
    expect(controller.textController.selection.baseOffset, 3);
  });

  test('首段无法上移、末段无法下移', () async {
    await controller.load();
    controller.textController.text = 'A\nB';
    controller.textController.selection = TextSelection.collapsed(offset: 0);

    controller.moveParagraph(up: true);
    expect(controller.textController.text, 'A\nB');

    controller.textController.selection = TextSelection.collapsed(offset: 2);
    controller.moveParagraph(up: false);
    expect(controller.textController.text, 'A\nB');
  });

  test('段落移动可撤销', () async {
    await controller.load();
    controller.textController.text = 'A\nB';
    controller.textController.selection = TextSelection.collapsed(offset: 2);

    controller.moveParagraph(up: true);
    expect(controller.textController.text, 'B\nA');

    controller.undo();

    expect(controller.textController.text, 'A\nB');
  });

  test('重命名章节后立即落库', () async {
    await controller.load();
    await controller.renameChapter('改名后的章节');

    expect(controller.title, '改名后的章节');
    final saved = await chapters.getChapter(chapterId);
    expect(saved!.title, '改名后的章节');
  });

  test('超过单章上限时提示但不阻断保存', () async {
    await controller.load();
    controller.textController.text = '字' * (EditorController.maxChapterWords + 1);

    expect(controller.chapterWords, EditorController.maxChapterWords + 1);
    expect(controller.overWordLimit, isTrue);

    await controller.flush();

    final saved = await chapters.getChapter(chapterId);
    expect(saved!.wordCount, EditorController.maxChapterWords + 1);
  });

  test('定位区间时选中该区间且不改动正文（M4-10）', () async {
    await controller.load();
    controller.textController.text = '她不禁笑了。';

    controller.revealRange(1, 3);

    expect(controller.textController.selection.baseOffset, 1);
    expect(controller.textController.selection.extentOffset, 3);
    expect(controller.textController.text, '她不禁笑了。');

    // 越界区间收敛到正文长度。
    controller.revealRange(2, 999);
    expect(controller.textController.selection.extentOffset, 6);
  });

  test('一键替换指定区间且可撤销（M4-11）', () async {
    await controller.load();
    controller.textController.text = '她不禁笑了。';

    final ok = controller.replaceRange(1, 3, '');

    expect(ok, isTrue);
    expect(controller.textController.text, '她笑了。');
    expect(controller.textController.selection.baseOffset, 1);

    controller.undo();

    expect(controller.textController.text, '她不禁笑了。');
  });

  test('替换非法区间返回 false（M4-11）', () async {
    await controller.load();
    controller.textController.text = '正文';

    expect(controller.replaceRange(3, 1, 'x'), isFalse);
    expect(controller.replaceRange(0, 99, 'x'), isFalse);
    expect(controller.textController.text, '正文');
  });
}