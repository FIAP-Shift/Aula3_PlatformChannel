import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_shift_platform_channel/model/message.dart';
import 'package:flutter_shift_platform_channel/util/constants.dart';

//essa classe controla o início do jogo
//para isso eu preciso saber se sou o criador do jogo ou o convidado
//e também, o nome do jogo
class WrapperCreator {

  final bool creator;
  final String nameGame;

  WrapperCreator(this.creator, this.nameGame);

}

class Game extends StatefulWidget {
  @override
  _GameState createState() => _GameState();
}

class _GameState extends State<Game> {

  TextStyle textStyle75 = TextStyle(
      fontSize: 75,
      color: Colors.white
  );

  TextStyle textStyle36 = TextStyle(
      fontSize: 36,
      color: Colors.white
  );

  bool minhaVez;
  WrapperCreator creator;

  // 0 = branco. 1 = eu. 2 - adversário
  List<List<int>> cells = [
    [0, 0, 0],
    [0, 0, 0],
    [0, 0, 0]
  ];

  static const platform = const MethodChannel('game/exchange');

  @override
  void initState() {
    super.initState();
    configureCallHandler();
  }

  void configureCallHandler(){
    //tratamos chamadas do código nativo para o dart
    platform.setMethodCallHandler((call) {
        String argumentos = call.arguments.toString();
        List<String> parts = argumentos.split("|");
        ExchangeMessage message = ExchangeMessage(parts[0], int.parse(parts[1]), int.parse(parts[2]));

        //só ouço mensagens do meu oponente
        if (message.user == (creator.creator ? 'p2' : 'p1')) {
          setState(() {
            minhaVez = true;
            cells[message.x][message.y] = 2;
          });
          //checkWinner();
        }

        return;
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    ScreenUtil.init(
        context,
        width: 700,
        height: 1400,
        allowFontScaling: false);

    return Scaffold(
      body: Stack(
        children: [
          buildFirstStack(),
          buildSecondStack()
        ],
      ),
    );
  }

  Widget buildSecondStack() => Container(
    height: ScreenUtil().setHeight(1400),
    child: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          creator == null ? Row(
            children: [
              buildButton("Criar", true),
              SizedBox(width: 10),
              buildButton("Entrar", false)
            ],
            mainAxisSize: MainAxisSize.min,
          ) : Text(
              minhaVez ? "Sua Vez!!" : "Aguarde Sua Vez!!!",
              style: textStyle36
          ),
          GridView.count(
            shrinkWrap: true,
            padding: EdgeInsets.all(20),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            crossAxisCount: 3,
            children: <Widget>[
              getCell(0, 0),
              getCell(0, 1),
              getCell(0, 2),
              getCell(1, 0),
              getCell(1, 1),
              getCell(1, 2),
              getCell(2, 0),
              getCell(2, 1),
              getCell(2, 2),
            ],
          ),
        ],
      ),
    ),
  );

  Widget buildFirstStack() => Column(
    children: [
      Row(
        children: [
          Container(
            width: ScreenUtil().setWidth(550),
            height: ScreenUtil().setHeight(550),
            color: colorBackBlue1,
          ),
          Container(
            width: ScreenUtil().setWidth(150),
            height: ScreenUtil().setHeight(550),
            color: colorBackBlue2,
          )
        ],
      ),
      Container(
        width: ScreenUtil().setWidth(700),
        height: ScreenUtil().setHeight(850),
        color: colorBackBlue3,
      )
    ],
  );

  Widget buildButton(String label, bool owner) => Container(
    width: ScreenUtil().setWidth(300),
    child: OutlineButton(
      child: Padding(
        padding: EdgeInsets.all(8.0),
        child: Text(
            label,
            style: textStyle36
        ),
      ),
      onPressed: (){
        createGame(owner);
      },
    ),
  );

  Future<void> createGame(bool isCreator) {
    TextEditingController editingController = TextEditingController();

    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Qual o nome do jogo?'),
          content: TextField(
            controller: editingController,
          ),
          actions: <Widget>[
            FlatButton(
              child: Text('Jogar'),
              onPressed: () {
                Navigator.of(context).pop();
                _sendAction(
                    'subscribe',//método desejado
                    {'channel': editingController.text}//argumento
                    ).then((value) { //ou usa then ou usa async-await
                  setState(() {
                    creator = WrapperCreator(isCreator, editingController.text);
                    minhaVez = isCreator;
                  });
                });
              },
            ),
          ],
        );
      },
    );
  }

  Widget getCell(int x, int y) => InkWell(
        child: Container(
          padding: EdgeInsets.all(8),
          child: Center(
              child: Text(
                  cells[x][y] == 0 ? " " : cells[x][y] == 1 ? "X" : "O",
                  style: textStyle75
              )
          ),
          color: Colors.lightBlueAccent,
        ),
        onTap: () {
          if (minhaVez && cells[x][y] == 0) {
            _showSendingAcion();
            _sendAction('sendAction', {'tap': '${creator.creator ? 'p1' : 'p2'}|$x|$y'})
                .then((value) {
                Navigator.of(context).pop();
                minhaVez = false;
                cells[x][y] = 1;

                setState(() {});
              //checkWinner();
            });
          }
        },
      );

  Future<bool> _sendAction(String action, Map<String, dynamic> arguments) async {
    try {
      //na linha de baixo estamos fazendo, efetivamente, a chamada a um método nativo
      final bool result = await platform.invokeMethod(action, arguments);
      if (result){
        return true;
      }
    } on PlatformException catch (e) {
      return false;
    }
  }

  Future<void> _showSendingAcion() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Enviando ação, aguarde...'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator()
            ],
          ),
        );
      },
    );
  }

}
