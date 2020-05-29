import 'dart:convert';
import 'dart:io';

import 'package:college_plan/momo_env/momo_constants.dart';
import 'package:college_plan/services/user_services.dart';
import 'package:device_info/device_info.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

// the unique ID of the application
const String _applicationId = "me.fonkamloic.college_plan";

// the storage key for the token
const String _storageKeyMobileToken = "token";

// the URL of the Web Server
const String _urlBase = "https://www.myserver.com";

// the URI to the Web Server Web API
const String _serverApi = "/api/mobile/";

// the mobile device unique identity
String _deviceIdentity = "";

/// ----------------------------------------------------------
/// Method which is only run once to fetch the device identity
/// ----------------------------------------------------------
final DeviceInfoPlugin _deviceInfoPlugin = new DeviceInfoPlugin();

Future<String> _getDeviceIdentity() async {
  if (_deviceIdentity == '') {
    try {
      if (Platform.isAndroid) {
        AndroidDeviceInfo info = await _deviceInfoPlugin.androidInfo;
        _deviceIdentity = "${info.device}-${info.id}";
      } else if (Platform.isIOS) {
        IosDeviceInfo info = await _deviceInfoPlugin.iosInfo;
        _deviceIdentity = "${info.model}-${info.identifierForVendor}";
      }
    } on PlatformException {
      _deviceIdentity = "unknown";
    }
  }

  return _deviceIdentity;
}

/// ----------------------------------------------------------
/// Method that returns the token from Shared Preferences
/// ----------------------------------------------------------

Future<SharedPreferences> _prefs = SharedPreferences.getInstance();

Future<String> _getMobileToken() async {
  final SharedPreferences prefs = await _prefs;

  return prefs.getString(_storageKeyMobileToken) ?? '';
}

/// ----------------------------------------------------------
/// Method that saves the token in Shared Preferences
/// ----------------------------------------------------------
Future<bool> _setMobileToken(String token) async {
  final SharedPreferences prefs = await _prefs;

  return prefs.setString(_storageKeyMobileToken, token);
}

/// ----------------------------------------------------------
/// Http Handshake
///
/// At application start up, the application needs to synchronize
/// with the server.
/// How does this work?
///   - A. If a previous token exists, the latter is sent to
///   -   the server to be validated.  If the validation is Ok,
///   -   the user is re-authenticated and a new token is returned
///   -   to the application.  The application then stores it.
///
///   - B. If no token exists, the application sends a request
///   -   for a new token to the server, which returns the
///   -   the requested token.  This token will be saved.
/// ----------------------------------------------------------
Future<String> handShake() async {
  String _status = "ERROR";

  return ajaxGet("handshake").then((String responseBody) async {
    Map response = json.decode(responseBody);
    _status = response["status"];
    switch (_status) {
      case "REQUIRES_AUTHENTICATION":
        // We received a new token, so let's save it.
        await _setMobileToken(response["data"]);
        break;

      case "INVALID":
        // The token we passed in invalid ??  why ?? somebody played with the local storage?
        // Anyways, we need to remove the previous one from the local storage,
        // and proceed with another handshake
        await _setMobileToken("");
        break;

      //TODO: add other cases
    }

    return _status;
  }).catchError(() {
    return "ERROR";
  });
}

/// ----------------------------------------------------------
/// Http "GET" request
/// ----------------------------------------------------------
Future<String> ajaxGet(String serviceName) async {
  var responseBody = '{"data": "", "status": "NOK"}';
  String apiUser = Uuid().v4();
  try {
    var response =
        await http.get(URL_SAND_PROVISION + '/apiuser', headers: {
      "X-Reference-Id": apiUser,
      HttpHeaders.contentTypeHeader: "x-www-form-urlencoded",
      "Ocp-Apim-Subscription-Key": PRIMARY_KEY_COLLECTION,
      'X-DEVICE-ID': await _getDeviceIdentity(),
      'X-TOKEN': await _getMobileToken(),
      'X-APP-ID': _applicationId
    });
    UserServices.alice.onHttpResponse(response);

    if (response.statusCode == 201) {
      responseBody = response.body;
    }
  } catch (e) {
    // An error was received
    throw new Exception("AJAX ERROR");
  }
  return responseBody;
}

/// ----------------------------------------------------------
/// Http "POST" request
/// ----------------------------------------------------------
Future<Map> ajaxPost(String serviceName, Map data) async {
  var responseBody = json.decode('{"data": "", "status": "NOK"}');

  try {
    var response = await http.post(_urlBase + '/$_serverApi$serviceName',
        body: json.encode(data),
        headers: {
          'X-DEVICE-ID': await _getDeviceIdentity(),
          'X-TOKEN': await _getMobileToken(),
          'X-APP-ID': _applicationId,
          'Content-Type': 'application/json; charset=utf-8'
        });
    if (response.statusCode == 200) {
      responseBody = json.decode(response.body);

      //
      // If we receive a new token, let's save it
      //
      if (responseBody["status"] == "TOKEN") {
        await _setMobileToken(responseBody["data"]);

        // TODO: rerun the Post request
      }
    }
  } catch (e) {
    // An error was received
    throw new Exception("AJAX ERROR");
  }
  return responseBody;
}

final authorizationEndpoint = Uri.parse(URL_SAND_PROVISION);
final tokenEndpoint = Uri.parse(URL_COLLECTION_TOKEN);

final identifier = APIUSER_COLLECTION;
final secret = APIKEY_COLLECTION;

abstract class MomoServices {
//  String _apiUser = APIUSER;
//  String _apiKey = APIKEY;
//  String _ocp_key = OCP_KEY;
//  String _credentials = CREDENTIAL;
  static String credentials_collection =
      base64.encode(utf8.encode(APIUSER_COLLECTION + ":" + APIKEY_COLLECTION));

  Dio dio = Dio();
  Uuid uuid = Uuid();

  Future<String> getCredential({String uuid}) {
    dio.interceptors.add(UserServices.alice.getDioInterceptor());
  }

  /*
    Collections
   */

  static Future<String> createUser_collection() async {
    String apiUser = Uuid().v4();
    Map<String, String> body = {"providerCallbackHost": CALLBACK_HOST};
    // dio.interceptors.add(UserServices.alice.getDioInterceptor());
    http.Response response = await http.post(
      "$URL_SAND_PROVISION/apiuser",
      body: await json.encode(body),
//      options: Options(
      headers: {
        "X-Reference-Id": apiUser,
        HttpHeaders.contentTypeHeader: "application/json",
        "Ocp-Apim-Subscription-Key": PRIMARY_KEY_COLLECTION,
        "Accept": "*/*",
        "Cache-Control": "no-cache",
        "Connection": "keep-alive",
        "Accept-Encoding": "gzip, deflate",
        "User-Agent": "PostmanRuntime/7.20.1",
//        "Content-Type": "application/json",
        "Postman-Token": APIUSER_DISBURSEMENT
      },
    );
    UserServices.alice.onHttpResponse(response);
    print(response.statusCode);
    print(response.body);
    if (response.statusCode == 201) {
      return apiUser;
    } else if (response.statusCode == 409) {
      print("Duplicate user");
      return null;
    }
  }

  static Future<bool> verifyUser_collection({String apiUser}) async {
    // dio.interceptors.add(UserServices.alice.getDioInterceptor());

    http.Response response =
        await http.get("$URL_SAND_PROVISION/apiuser/$apiUser",
//        options: Options(
            headers: {
          "Ocp-Apim-Subscription-Key": PRIMARY_KEY_COLLECTION,
        }
//        )

            );
    //BotToast.showText(text: response.data['apikey']);
    if (response.statusCode == 200) {
      return true;
    }
  }

  static Future<String> getApiKeyForVerifiedUser_collection(
      {String apiUser}) async {
    //  dio.interceptors.add(UserServices.alice.getDioInterceptor());
    http.Response response = await http.post(
      "$URL_SAND_PROVISION/apiuser/$apiUser/apikey",
//      options: Options(
      headers: {
        "Ocp-Apim-Subscription-Key": PRIMARY_KEY_COLLECTION,
      },
//      ),
    );
    if (response.statusCode == 201) {
      return json.decode(response.body)["apiKey"];
    }
  }

  static Future<String> getToken_collection({String credentials}) async {
    //   dio.interceptors.add(UserServices.alice.getDioInterceptor());

    http.Response response = await http.post('$URL_COLLECTION_TOKEN/token/',
//      options: Options(
        headers: {
          "Authorization": "Basic $credentials_collection",
          "Ocp-Apim-Subscription-Key": PRIMARY_KEY_COLLECTION,
          "X-DEVICE-ID": await _getDeviceIdentity(),
          "X-TOKEN": await _getMobileToken(),
          "X-APP-ID": _applicationId
        }
//      ),
        );
    UserServices.alice.onHttpResponse(response);

    if (response.statusCode == 200) {
      return json.decode(response.body)["access_token"];
    }
  }

  static Future<String> resquestToPay_collection({
    String amount,
    String token,
    String number,
    String uuid,
  }) async {
    //  dio.interceptors.add(UserServices.alice.getDioInterceptor());

    http.Response response = await http.post("$URL_COLLECTION/requesttopay",
//      options: Options(

        headers: {
          HttpHeaders.authorizationHeader: "Bearer $token",
          "X-Callback-Url": CALLBACK_HOST,
          "X-Reference-Id": uuid,
          "X-Target-Environment": "sandbox",
          "Content-Type": "application/json",
          "Ocp-Apim-Subscription-Key": PRIMARY_KEY_COLLECTION,
//        "X-DEVICE-ID": await _getDeviceIdentity(),
//        "X-TOKEN": await _getMobileToken(),
//        "X-APP-ID": _applicationId
        },
//      ),
        body: {
          "amount": amount,
          "currency": "EUR",
          "externalId": "1234785",
          "payer": {"partyIdType": "MSISDN", "partyId": number},
          "payerMessage": "CollegePlan",
          "payeeNote": "CollegePlan"
        });
    UserServices.alice.onHttpResponse(response);
    if (response.statusCode == 202) {
      return 'Successful';
    }
  }

  static Future<String> requestToPayStatus_collection({
    String apiUser,
    String token,
  }) async {
    // dio.interceptors.add(UserServices.alice.getDioInterceptor());
    http.Response response =
        await http.get('$URL_COLLECTION/requesttopay/$apiUser',
//      options: Options(

            headers: {
          "Authorization": "Bearer $token",
          "X-Target-Environment": "sandbox",
          "Ocp-Apim-Subscription-Key": PRIMARY_KEY_COLLECTION,
        }
//      ),
            );
    if (response.statusCode == 200) {
      return json.decode(response.body)["status"];
    }
  }

  static Future<String> getAccountBalance_collection({
    String number,
    String token,
  }) async {
    // dio.interceptors.add(UserServices.alice.getDioInterceptor());
    http.Response response = await http.get(
      '$URL_COLLECTION/account/balance',
      //  options: Options(
      headers: {
        "Authorization": "Basic $token",
        "X-Target-Environment": "sandbox",
        "Ocp-Apim-Subscription-Key": PRIMARY_KEY_COLLECTION,
        "Accept": "*/*",
        "Cache-Control": "no-cache",
        "Connection": "keep-alive",
        "Accept-Encoding": "gzip, deflate",

        "Content-Type": "application/json",
        "X-DEVICE-ID": APIUSER_DISBURSEMENT,
////        "X-TOKEN": await _getMobileToken(),
////        "X-APP-ID": _applicationId
      },
      //   ),
    );
    UserServices.alice.onHttpResponse(response);

    if (response.statusCode == 200) {
      return json.decode(response.body)["availableBalance"];
    } else {
      print(response.body);
      return "34,8";
    }
  }

  static String checkRegisteredAccountHolder_collection({String token}) {
    // dio.interceptors.add(UserServices.alice.getDioInterceptor());
    Map<String, String> type_id = {
      "msisdn": "IsMSISDN",
      "email": "IsEmail",
      "party_code": "IsUuid"
    };
    String accountType;
    http.Response response;
    type_id.forEach((type, id) async {
      response =
          await http.get('$URL_COLLECTION/accountholder/$type/$id/active');
      if (response.statusCode == 200) {
        accountType = type;
      }
    });
    return accountType;
  }

  /*
      Disbursement
   */

  static Future<String> createUser_disbursement() async {
    String apiUser = Uuid().v4();
    //  dio.interceptors.add(UserServices.alice.getDioInterceptor());
    http.Response response = await http.post(
      "$URL_SAND_PROVISION/apiuser",
//      options: Options(
      headers: {
        "X-Reference-Id": apiUser,
        "Content-Type": "application/json",
        "Ocp-Apim-Subscription-Key": PRIMARY_KEY_DISBURSE,
      },
      // method: "POST",
//      ),
      body: json.encode('{"providerCallbackHost": $CALLBACK_HOST }'),
    );

    print(response.statusCode);
    print(json.decode(response.body));
    if (response.statusCode == 201) {
      return apiUser;
    } else if (response.statusCode == 409) {
      print("Duplicate user");
      return null;
    }
  }

  static Future<bool> verifyUser_disbursement({String apiUser}) async {
//    dio.interceptors.add(UserServices.alice.getDioInterceptor());

    http.Response response =
        await http.get("$URL_SAND_PROVISION/apiuser/$apiUser",
//        options: Options(
            headers: {
          "Ocp-Apim-Subscription-Key": PRIMARY_KEY_DISBURSE,
        }
//        )
            );
    if (response.statusCode == 200) {
      return true;
    }
  }

  static Future<String> getApiKeyForVerifiedUser_disbursement(
      {String apiUser}) async {
//    dio.interceptors.add(UserServices.alice.getDioInterceptor());
    http.Response response = await http.post(
      "$URL_SAND_PROVISION/apiuser/$apiUser/apikey",
//      options: Options(
      headers: {
        "Ocp-Apim-Subscription-Key": PRIMARY_KEY_DISBURSE,
      },
//      ),
    );
    if (response.statusCode == 201) {
      return json.decode(response.body)["apiKey"];
    }
  }

  static Future<String> getToken_disbursement({String credentials}) async {
//    dio.interceptors.add(UserServices.alice.getDioInterceptor());

    http.Response response = await http.post('$URL_COLLECTION_TOKEN/token/',
//      options: Options(
        headers: {
          "Authorization": "Basic $credentials",
          "Ocp-Apim-Subscription-Key": PRIMARY_KEY_DISBURSE,
        }
//      ),
        );

    if (response.statusCode == 200) {
      return json.decode(response.body)["access_token"];
    }
  }

  static Future<String> transfer_disbursement({
    String token,
    String number,
    String amount,
    String uuid,
  }) async {
//    dio.interceptors.add(UserServices.alice.getDioInterceptor());

    http.Response response = await http.post(
      "$URL_DISBURSEMENT/transfer",
//      options: Options(
      headers: {
        "Authorization": "Bearer " + token,
        "X-Callback-Url": CALLBACK_HOST,
        "X-Reference-Id": uuid,
        "X-Target-Environment": TARGET_ENV,
        "Content-Type": "application/json",
        "Ocp-Apim-Subscription-Key": PRIMARY_KEY_DISBURSE,
      },

//      ),
      body: json.encode(
          '{"amount": $amount, "currency": "EUR", "externalId": "4312345",  "payer": {"partyIdType": "MSISDN", "partyId": $number},  "payerMessage": "CollegePlan",   "payeeNote": "CollegePlan"      }'),
    );

    if (response.statusCode == 202) {
      return json.decode(response.body)["status"];
    }
  }

  Future<String> getTransferStatus_disbursement({
    String apiUser,
    String token,
  }) async {
//    dio.interceptors.add(UserServices.alice.getDioInterceptor());
    http.Response response = await http.get(
      '$URL_DISBURSEMENT/transfer/$apiUser',
//      options: Options(
      headers: {
        "Authorization": "Bearer " + token,
        "X-Target-Environment": TARGET_ENV,
        "Ocp-Apim-Subscription-Key": PRIMARY_KEY_DISBURSE,
      },
//      ),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body)["status"];
    }
  }

  static Future<String> getAccountBalance_disbursement({
//    String number,
    String token,
  }) async {
//    dio.interceptors.add(UserServices.alice.getDioInterceptor());
    http.Response response = await http.get(
      '$URL_DISBURSEMENT/account/balance',
//      options: Options(
      headers: {
        "Authorization": "Bearer " + token,
        "X-Target-Environment": "sandbox",
        "Ocp-Apim-Subscription-Key": PRIMARY_KEY_DISBURSE,
      },
//      ),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body)["availableBalance"];
    }
  }

  static String checkRegisteredAccountHolder_disbursement({String token}) {
//    dio.interceptors.add(UserServices.alice.getDioInterceptor());
    Map<String, String> type_id = {
      "msisdn": "IsMSISDN",
      "email": "IsEmail",
      "party_code": "IsUuid"
    };
    String accountType;
    http.Response response;
    type_id.forEach((type, id) async {
      response =
          await http.get('$URL_DISBURSEMENT/accountholder/$type/$id/active?');
      if (response.statusCode == 200) {
        accountType = type;
      }
    });
    return accountType;
  }

/*


var response = await http.get('https://www.myserver.com/api/mobile/handshake',
				headers: {
				  'X-DEVICE-ID': 'my_device_id',
				  'X-TOKEN': '',
				  'X-APP-ID': 'my_application_id'
				});

if (response.statusCode == 200) {
  String token = response.body;
}
*/

}
//jsonObject = {
//status: 'result status',
//data: 'data, returned by the Server'
//};
