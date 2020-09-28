package ogliari.flutter.flutter_shift_platform_channel

import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.annotation.NonNull
import com.pubnub.api.PNConfiguration
import com.pubnub.api.PubNub
import com.pubnub.api.callbacks.SubscribeCallback
import com.pubnub.api.models.consumer.PNStatus
import com.pubnub.api.models.consumer.pubsub.PNMessageResult
import com.pubnub.api.models.consumer.pubsub.PNPresenceEventResult
import com.pubnub.api.models.consumer.pubsub.PNSignalResult
import com.pubnub.api.models.consumer.pubsub.message_actions.PNMessageActionResult
import com.pubnub.api.models.consumer.pubsub.objects.PNMembershipResult
import com.pubnub.api.models.consumer.pubsub.objects.PNSpaceResult
import com.pubnub.api.models.consumer.pubsub.objects.PNUserResult
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Arrays

class MainActivity: FlutterActivity() {

    private val CHANNEL = "game/exchange"
    private var pubnub: PubNub? = null
    private var channel: String? = null
    private var handler: Handler? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        handler = Handler(Looper.getMainLooper())

        //criem suas chaves , porque essas serão removidas daqui 1 ou 2 semanas
        //fácil fácil no página do pubnub
        val pnConfiguration = PNConfiguration()
        pnConfiguration.subscribeKey = "sub-c-b46b44f4-b357-11ea-a40b-6ab2c237bf6e"
        pnConfiguration.publishKey = "pub-c-e64c54b3-4076-4638-a0d6-f17d9a5e5442"
        pnConfiguration.uuid = "myUniqueUUID"
        pubnub = PubNub(pnConfiguration)

        //PUBNUB é o canal na nuvem, ou seja, ele é o middleware entre os agentes do jogo
        pubnub?.let {
            it.addListener(object : SubscribeCallback() {
                override fun status(pubnub: PubNub, status: PNStatus) { }

                override fun message(pubnub: PubNub, message: PNMessageResult) {
                    //aqui tratamos a mensagem recebida do pubnub e precisamos enviar
                    //ao código DART
                    val receivedMessageObject = message.message.asJsonObject["tap"]
                    Log.e("pubnub", "Received message content: $receivedMessageObject")

                    handler?.let {
                        it.post {
                            //chgamada do nativo pro dart
                            MethodChannel(flutterEngine?.dartExecutor?.binaryMessenger, CHANNEL)
                                .invokeMethod(
                                    "sendAction",
                                    "${receivedMessageObject.asString}"
                                );
                        }
                    }
                }

                override fun presence(pubnub: PubNub, presence: PNPresenceEventResult) {}
                override fun signal(pubnub: PubNub, pnSignalResult: PNSignalResult) {}
                override fun user(pubnub: PubNub, pnUserResult: PNUserResult) {}
                override fun messageAction(pubnub: PubNub, pnMessageActionResult: PNMessageActionResult) {}
                override fun membership(pubnub: PubNub, pnMembershipResult: PNMembershipResult) {}
                override fun space(pubnub: PubNub, pnSpaceResult: PNSpaceResult) {}
            })
        }

    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        //METHODCHANNEL é o canal entre o nativo e o dart (não confundam com o canal do Pubnub)
        //com o setMethodCallHandler, nós ouvimos requisições do DART a serem tratadas pelo lado nativo
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
            call, result ->
            //tratamento dos métodos requisitados pelo DART
            if (call.method == "sendAction") {
                pubnub!!.publish()
                    .message(call.arguments)
                    .channel(channel)
                    .async { result, status ->
                        Log.e( "pubnub","teve erro? ${status.isError}")
                    }
                result.success(true)
            } else if (call.method == "subscribe") {
                subscribeChannel(call.argument("channel"))
                result.success(true)
            } else {
                result.notImplemented()
            }
        }
    }

    fun subscribeChannel(channelName: String?){
        channel = channelName
        channelName?.let {
            pubnub?.subscribe()?.channels(Arrays.asList(channelName))?.execute();
        }
    }

}
