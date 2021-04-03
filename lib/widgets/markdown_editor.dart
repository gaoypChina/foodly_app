import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

class MarkdownEditor extends StatefulWidget {
  final String initialValue;
  final TextEditingController textEditingController;
  final void Function(String) onChange;

  MarkdownEditor({
    Key key,
    this.initialValue,
    this.textEditingController,
    this.onChange,
  })  : assert((initialValue != null && textEditingController == null) ||
            (initialValue == null && textEditingController != null)),
        super(key: key);

  @override
  _MarkdownEditorState createState() => _MarkdownEditorState();
}

class _MarkdownEditorState extends State<MarkdownEditor>
    with TickerProviderStateMixin {
  TabController _tabController;
  String _content;

  @override
  void initState() {
    super.initState();
    _tabController = new TabController(vsync: this, length: 2);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _content = widget.initialValue ?? '';
    final textColor = Theme.of(context).textTheme.bodyText1.color;
    return Container(
      width: MediaQuery.of(context).size.width > 599
          ? 600.0
          : MediaQuery.of(context).size.width * 0.9,
      height: MediaQuery.of(context).size.height < 500
          ? 250.0
          : MediaQuery.of(context).size.height > 1000
              ? 600.0
              : MediaQuery.of(context).size.height * 0.5,
      child: Column(
        children: [
          TabBar(
            controller: _tabController,
            indicatorColor: textColor,
            tabs: [
              Tab(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    Icon(EvaIcons.editOutline, color: textColor),
                    SizedBox(width: 8.0),
                    Text('Bearbeiten', style: TextStyle(color: textColor)),
                  ],
                ),
              ),
              Tab(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    Icon(EvaIcons.eyeOutline, color: textColor),
                    SizedBox(width: 8.0),
                    Text('Vorschau', style: TextStyle(color: textColor)),
                  ],
                ),
              )
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: 5.0,
                    horizontal: 20.0,
                  ),
                  child: Scrollbar(
                    thickness: 2.5,
                    child: TextFormField(
                      initialValue:
                          widget.initialValue != null ? _content : null,
                      controller: widget.textEditingController != null
                          ? widget.textEditingController
                          : null,
                      maxLines: null,
                      onChanged: onContentChanged,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText:
                            '# Title\n## Subtitle\n- The quick brown fox jumps over the lazy dog\n- Lorem ipsum dolor sit amet, ...',
                      ),
                      minLines: 6,
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: 5.0,
                    horizontal: 20.0,
                  ),
                  child: Scrollbar(
                    thickness: 2.5,
                    child: SingleChildScrollView(
                      child: MarkdownBody(
                        data: widget.initialValue != null
                            ? _content
                            : widget.textEditingController.text,
                        selectable: true,
                        onTapLink: (_, href, __) => linkOnTapHandler(href),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(width: 1.0, color: Colors.black38),
              ),
            ),
            child: GestureDetector(
              onTap: () => linkOnTapHandler('https://commonmark.org/help/'),
              child: Padding(
                padding: EdgeInsets.all(10.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text('Formatiere den Text (klick für mehr Info).'),
                    Image.asset('assets/images/md-icon.png', width: 30.0),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void onContentChanged(String data) {
    if (widget.initialValue != null) {
      setState(() {
        _content = data;
      });
      widget.onChange(data);
    }
  }

  void linkOnTapHandler(String href) async {
    if (await canLaunch(href)) {
      await launch(href);
    } else {
      print('Could not launch $href');
    }
  }
}
