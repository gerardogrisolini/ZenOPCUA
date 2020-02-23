//
//  StatusCodes.swift
//  
//
//  Created by Gerardo Grisolini on 19/02/2020.
//

public enum StatusCodes: UInt32 {
    
    /* These StatusCodes are manually generated. */
    case UA_STATUSCODE_GOOD = 0x00
    case UA_STATUSCODE_INFOTYPE_DATAVALUE = 0x00000400
    case UA_STATUSCODE_INFOBITS_OVERFLOW = 0x00000080

    /* An unexpected error occurred. */
    case UA_STATUSCODE_BADUNEXPECTEDERROR = 0x80010000

    /* An internal error occurred as a result of a programming or configuration error. */
    case UA_STATUSCODE_BADINTERNALERROR = 0x80020000

    /* Not enough memory to complete the operation. */
    case UA_STATUSCODE_BADOUTOFMEMORY = 0x80030000

    /* An operating system resource is not available. */
    case UA_STATUSCODE_BADRESOURCEUNAVAILABLE = 0x80040000

    /* A low level communication error occurred. */
    case UA_STATUSCODE_BADCOMMUNICATIONERROR = 0x80050000

    /* Encoding halted because of invalid data in the objects being serialized. */
    case UA_STATUSCODE_BADENCODINGERROR = 0x80060000

    /* Decoding halted because of invalid data in the stream. */
    case UA_STATUSCODE_BADDECODINGERROR = 0x80070000

    /* The message encoding/decoding limits imposed by the stack have been exceeded. */
    case UA_STATUSCODE_BADENCODINGLIMITSEXCEEDED = 0x80080000

    /* The request message size exceeds limits set by the server. */
    case UA_STATUSCODE_BADREQUESTTOOLARGE = 0x80B80000

    /* The response message size exceeds limits set by the client. */
    case UA_STATUSCODE_BADRESPONSETOOLARGE = 0x80B90000

    /* An unrecognized response was received from the server. */
    case UA_STATUSCODE_BADUNKNOWNRESPONSE = 0x80090000

    /* The operation timed out. */
    case UA_STATUSCODE_BADTIMEOUT = 0x800A0000

    /* The server does not support the requested service. */
    case UA_STATUSCODE_BADSERVICEUNSUPPORTED = 0x800B0000

    /* The operation was cancelled because the application is shutting down. */
    case UA_STATUSCODE_BADSHUTDOWN = 0x800C0000

    /* The operation could not complete because the client is not connected to the server. */
    case UA_STATUSCODE_BADSERVERNOTCONNECTED = 0x800D0000

    /* The server has stopped and cannot process any requests. */
    case UA_STATUSCODE_BADSERVERHALTED = 0x800E0000

    /* There was nothing to do because the client passed a list of operations with no elements. */
    case UA_STATUSCODE_BADNOTHINGTODO = 0x800F0000

    /* The request could not be processed because it specified too many operations. */
    case UA_STATUSCODE_BADTOOMANYOPERATIONS = 0x80100000

    /* The request could not be processed because there are too many monitored items in the subscription. */
    case UA_STATUSCODE_BADTOOMANYMONITOREDITEMS = 0x80DB0000

    /* The extension object cannot be (de)serialized because the data type id is not recognized. */
    case UA_STATUSCODE_BADDATATYPEIDUNKNOWN = 0x80110000

    /* The certificate provided as a parameter is not valid. */
    case UA_STATUSCODE_BADCERTIFICATEINVALID = 0x80120000

    /* An error occurred verifying security. */
    case UA_STATUSCODE_BADSECURITYCHECKSFAILED = 0x80130000

    /* The certificate does not meet the requirements of the security policy. */
    case UA_STATUSCODE_BADCERTIFICATEPOLICYCHECKFAILED = 0x81140000

    /* The certificate has expired or is not yet valid. */
    case UA_STATUSCODE_BADCERTIFICATETIMEINVALID = 0x80140000

    /* An issuer certificate has expired or is not yet valid. */
    case UA_STATUSCODE_BADCERTIFICATEISSUERTIMEINVALID = 0x80150000

    /* The HostName used to connect to a server does not match a HostName in the certificate. */
    case UA_STATUSCODE_BADCERTIFICATEHOSTNAMEINVALID = 0x80160000

    /* The URI specified in the ApplicationDescription does not match the URI in the certificate. */
    case UA_STATUSCODE_BADCERTIFICATEURIINVALID = 0x80170000

    /* The certificate may not be used for the requested operation. */
    case UA_STATUSCODE_BADCERTIFICATEUSENOTALLOWED = 0x80180000

    /* The issuer certificate may not be used for the requested operation. */
    case UA_STATUSCODE_BADCERTIFICATEISSUERUSENOTALLOWED = 0x80190000

    /* The certificate is not trusted. */
    case UA_STATUSCODE_BADCERTIFICATEUNTRUSTED = 0x801A0000

    /* It was not possible to determine if the certificate has been revoked. */
    case UA_STATUSCODE_BADCERTIFICATEREVOCATIONUNKNOWN = 0x801B0000

    /* It was not possible to determine if the issuer certificate has been revoked. */
    case UA_STATUSCODE_BADCERTIFICATEISSUERREVOCATIONUNKNOWN = 0x801C0000

    /* The certificate has been revoked. */
    case UA_STATUSCODE_BADCERTIFICATEREVOKED = 0x801D0000

    /* The issuer certificate has been revoked. */
    case UA_STATUSCODE_BADCERTIFICATEISSUERREVOKED = 0x801E0000

    /* The certificate chain is incomplete. */
    case UA_STATUSCODE_BADCERTIFICATECHAININCOMPLETE = 0x810D0000

    /* User does not have permission to perform the requested operation. */
    case UA_STATUSCODE_BADUSERACCESSDENIED = 0x801F0000

    /* The user identity token is not valid. */
    case UA_STATUSCODE_BADIDENTITYTOKENINVALID = 0x80200000

    /* The user identity token is valid but the server has rejected it. */
    case UA_STATUSCODE_BADIDENTITYTOKENREJECTED = 0x80210000

    /* The specified secure channel is no longer valid. */
    case UA_STATUSCODE_BADSECURECHANNELIDINVALID = 0x80220000

    /* The timestamp is outside the range allowed by the server. */
    case UA_STATUSCODE_BADINVALIDTIMESTAMP = 0x80230000

    /* The nonce does appear to be not a random value or it is not the correct length. */
    case UA_STATUSCODE_BADNONCEINVALID = 0x80240000

    /* The session id is not valid. */
    case UA_STATUSCODE_BADSESSIONIDINVALID = 0x80250000

    /* The session was closed by the client. */
    case UA_STATUSCODE_BADSESSIONCLOSED = 0x80260000

    /* The session cannot be used because ActivateSession has not been called. */
    case UA_STATUSCODE_BADSESSIONNOTACTIVATED = 0x80270000

    /* The subscription id is not valid. */
    case UA_STATUSCODE_BADSUBSCRIPTIONIDINVALID = 0x80280000

    /* The header for the request is missing or invalid. */
    case UA_STATUSCODE_BADREQUESTHEADERINVALID = 0x802A0000

    /* The timestamps to return parameter is invalid. */
    case UA_STATUSCODE_BADTIMESTAMPSTORETURNINVALID = 0x802B0000

    /* The request was cancelled by the client. */
    case UA_STATUSCODE_BADREQUESTCANCELLEDBYCLIENT = 0x802C0000

    /* Too many arguments were provided. */
    case UA_STATUSCODE_BADTOOMANYARGUMENTS = 0x80E50000

    /* The server requires a license to operate in general or to perform a service or operation */
    case UA_STATUSCODE_BADLICENSEEXPIRED = 0x810E0000

    /* The server has limits on number of allowed operations / objects */
    case UA_STATUSCODE_BADLICENSELIMITSEXCEEDED = 0x810F0000

    /* The server does not have a license which is required to operate in general or to perform a service or operation. */
    case UA_STATUSCODE_BADLICENSENOTAVAILABLE = 0x81100000

    /* The subscription was transferred to another session. */
    case UA_STATUSCODE_GOODSUBSCRIPTIONTRANSFERRED = 0x002D0000

    /* The processing will complete asynchronously. */
    case UA_STATUSCODE_GOODCOMPLETESASYNCHRONOUSLY = 0x002E0000

    /* Sampling has slowed down due to resource limitations. */
    case UA_STATUSCODE_GOODOVERLOAD = 0x002F0000

    /* The value written was accepted but was clamped. */
    case UA_STATUSCODE_GOODCLAMPED = 0x00300000

    /* Communication with the data source is defined */
    case UA_STATUSCODE_BADNOCOMMUNICATION = 0x80310000

    /* Waiting for the server to obtain values from the underlying data source. */
    case UA_STATUSCODE_BADWAITINGFORINITIALDATA = 0x80320000

    /* The syntax of the node id is not valid. */
    case UA_STATUSCODE_BADNODEIDINVALID = 0x80330000

    /* The node id refers to a node that does not exist in the server address space. */
    case UA_STATUSCODE_BADNODEIDUNKNOWN = 0x80340000

    /* The attribute is not supported for the specified Node. */
    case UA_STATUSCODE_BADATTRIBUTEIDINVALID = 0x80350000

    /* The syntax of the index range parameter is invalid. */
    case UA_STATUSCODE_BADINDEXRANGEINVALID = 0x80360000

    /* No data exists within the range of indexes specified. */
    case UA_STATUSCODE_BADINDEXRANGENODATA = 0x80370000

    /* The data encoding is invalid. */
    case UA_STATUSCODE_BADDATAENCODINGINVALID = 0x80380000

    /* The server does not support the requested data encoding for the node. */
    case UA_STATUSCODE_BADDATAENCODINGUNSUPPORTED = 0x80390000

    /* The access level does not allow reading or subscribing to the Node. */
    case UA_STATUSCODE_BADNOTREADABLE = 0x803A0000

    /* The access level does not allow writing to the Node. */
    case UA_STATUSCODE_BADNOTWRITABLE = 0x803B0000

    /* The value was out of range. */
    case UA_STATUSCODE_BADOUTOFRANGE = 0x803C0000

    /* The requested operation is not supported. */
    case UA_STATUSCODE_BADNOTSUPPORTED = 0x803D0000

    /* A requested item was not found or a search operation ended without success. */
    case UA_STATUSCODE_BADNOTFOUND = 0x803E0000

    /* The object cannot be used because it has been deleted. */
    case UA_STATUSCODE_BADOBJECTDELETED = 0x803F0000

    /* Requested operation is not implemented. */
    case UA_STATUSCODE_BADNOTIMPLEMENTED = 0x80400000

    /* The monitoring mode is invalid. */
    case UA_STATUSCODE_BADMONITORINGMODEINVALID = 0x80410000

    /* The monitoring item id does not refer to a valid monitored item. */
    case UA_STATUSCODE_BADMONITOREDITEMIDINVALID = 0x80420000

    /* The monitored item filter parameter is not valid. */
    case UA_STATUSCODE_BADMONITOREDITEMFILTERINVALID = 0x80430000

    /* The server does not support the requested monitored item filter. */
    case UA_STATUSCODE_BADMONITOREDITEMFILTERUNSUPPORTED = 0x80440000

    /* A monitoring filter cannot be used in combination with the attribute specified. */
    case UA_STATUSCODE_BADFILTERNOTALLOWED = 0x80450000

    /* A mandatory structured parameter was missing or null. */
    case UA_STATUSCODE_BADSTRUCTUREMISSING = 0x80460000

    /* The event filter is not valid. */
    case UA_STATUSCODE_BADEVENTFILTERINVALID = 0x80470000

    /* The content filter is not valid. */
    case UA_STATUSCODE_BADCONTENTFILTERINVALID = 0x80480000

    /* An unrecognized operator was provided in a filter. */
    case UA_STATUSCODE_BADFILTEROPERATORINVALID = 0x80C10000

    /* A valid operator was provided */
    case UA_STATUSCODE_BADFILTEROPERATORUNSUPPORTED = 0x80C20000

    /* The number of operands provided for the filter operator was less then expected for the operand provided. */
    case UA_STATUSCODE_BADFILTEROPERANDCOUNTMISMATCH = 0x80C30000

    /* The operand used in a content filter is not valid. */
    case UA_STATUSCODE_BADFILTEROPERANDINVALID = 0x80490000

    /* The referenced element is not a valid element in the content filter. */
    case UA_STATUSCODE_BADFILTERELEMENTINVALID = 0x80C40000

    /* The referenced literal is not a valid value. */
    case UA_STATUSCODE_BADFILTERLITERALINVALID = 0x80C50000

    /* The continuation point provide is longer valid. */
    case UA_STATUSCODE_BADCONTINUATIONPOINTINVALID = 0x804A0000

    /* The operation could not be processed because all continuation points have been allocated. */
    case UA_STATUSCODE_BADNOCONTINUATIONPOINTS = 0x804B0000

    /* The reference type id does not refer to a valid reference type node. */
    case UA_STATUSCODE_BADREFERENCETYPEIDINVALID = 0x804C0000

    /* The browse direction is not valid. */
    case UA_STATUSCODE_BADBROWSEDIRECTIONINVALID = 0x804D0000

    /* The node is not part of the view. */
    case UA_STATUSCODE_BADNODENOTINVIEW = 0x804E0000

    /* The number was not accepted because of a numeric overflow. */
    case UA_STATUSCODE_BADNUMERICOVERFLOW = 0x81120000

    /* The ServerUri is not a valid URI. */
    case UA_STATUSCODE_BADSERVERURIINVALID = 0x804F0000

    /* No ServerName was specified. */
    case UA_STATUSCODE_BADSERVERNAMEMISSING = 0x80500000

    /* No DiscoveryUrl was specified. */
    case UA_STATUSCODE_BADDISCOVERYURLMISSING = 0x80510000

    /* The semaphore file specified by the client is not valid. */
    case UA_STATUSCODE_BADSEMPAHOREFILEMISSING = 0x80520000

    /* The security token request type is not valid. */
    case UA_STATUSCODE_BADREQUESTTYPEINVALID = 0x80530000

    /* The security mode does not meet the requirements set by the server. */
    case UA_STATUSCODE_BADSECURITYMODEREJECTED = 0x80540000

    /* The security policy does not meet the requirements set by the server. */
    case UA_STATUSCODE_BADSECURITYPOLICYREJECTED = 0x80550000

    /* The server has reached its maximum number of sessions. */
    case UA_STATUSCODE_BADTOOMANYSESSIONS = 0x80560000

    /* The user token signature is missing or invalid. */
    case UA_STATUSCODE_BADUSERSIGNATUREINVALID = 0x80570000

    /* The signature generated with the client certificate is missing or invalid. */
    case UA_STATUSCODE_BADAPPLICATIONSIGNATUREINVALID = 0x80580000

    /* The client did not provide at least one software certificate that is valid and meets the profile requirements for the server. */
    case UA_STATUSCODE_BADNOVALIDCERTIFICATES = 0x80590000

    /* The server does not support changing the user identity assigned to the session. */
    case UA_STATUSCODE_BADIDENTITYCHANGENOTSUPPORTED = 0x80C60000

    /* The request was cancelled by the client with the Cancel service. */
    case UA_STATUSCODE_BADREQUESTCANCELLEDBYREQUEST = 0x805A0000

    /* The parent node id does not to refer to a valid node. */
    case UA_STATUSCODE_BADPARENTNODEIDINVALID = 0x805B0000

    /* The reference could not be created because it violates constraints imposed by the data model. */
    case UA_STATUSCODE_BADREFERENCENOTALLOWED = 0x805C0000

    /* The requested node id was reject because it was either invalid or server does not allow node ids to be specified by the client. */
    case UA_STATUSCODE_BADNODEIDREJECTED = 0x805D0000

    /* The requested node id is already used by another node. */
    case UA_STATUSCODE_BADNODEIDEXISTS = 0x805E0000

    /* The node class is not valid. */
    case UA_STATUSCODE_BADNODECLASSINVALID = 0x805F0000

    /* The browse name is invalid. */
    case UA_STATUSCODE_BADBROWSENAMEINVALID = 0x80600000

    /* The browse name is not unique among nodes that share the same relationship with the parent. */
    case UA_STATUSCODE_BADBROWSENAMEDUPLICATED = 0x80610000

    /* The node attributes are not valid for the node class. */
    case UA_STATUSCODE_BADNODEATTRIBUTESINVALID = 0x80620000

    /* The type definition node id does not reference an appropriate type node. */
    case UA_STATUSCODE_BADTYPEDEFINITIONINVALID = 0x80630000

    /* The source node id does not reference a valid node. */
    case UA_STATUSCODE_BADSOURCENODEIDINVALID = 0x80640000

    /* The target node id does not reference a valid node. */
    case UA_STATUSCODE_BADTARGETNODEIDINVALID = 0x80650000

    /* The reference type between the nodes is already defined. */
    case UA_STATUSCODE_BADDUPLICATEREFERENCENOTALLOWED = 0x80660000

    /* The server does not allow this type of self reference on this node. */
    case UA_STATUSCODE_BADINVALIDSELFREFERENCE = 0x80670000

    /* The reference type is not valid for a reference to a remote server. */
    case UA_STATUSCODE_BADREFERENCELOCALONLY = 0x80680000

    /* The server will not allow the node to be deleted. */
    case UA_STATUSCODE_BADNODELETERIGHTS = 0x80690000

    /* The server was not able to delete all target references. */
    case UA_STATUSCODE_UNCERTAINREFERENCENOTDELETED = 0x40BC0000

    /* The server index is not valid. */
    case UA_STATUSCODE_BADSERVERINDEXINVALID = 0x806A0000

    /* The view id does not refer to a valid view node. */
    case UA_STATUSCODE_BADVIEWIDUNKNOWN = 0x806B0000

    /* The view timestamp is not available or not supported. */
    case UA_STATUSCODE_BADVIEWTIMESTAMPINVALID = 0x80C90000

    /* The view parameters are not consistent with each other. */
    case UA_STATUSCODE_BADVIEWPARAMETERMISMATCH = 0x80CA0000

    /* The view version is not available or not supported. */
    case UA_STATUSCODE_BADVIEWVERSIONINVALID = 0x80CB0000

    /* The list of references may not be complete because the underlying system is not available. */
    case UA_STATUSCODE_UNCERTAINNOTALLNODESAVAILABLE = 0x40C00000

    /* The server should have followed a reference to a node in a remote server but did not. The result set may be incomplete. */
    case UA_STATUSCODE_GOODRESULTSMAYBEINCOMPLETE = 0x00BA0000

    /* The provided Nodeid was not a type definition nodeid. */
    case UA_STATUSCODE_BADNOTTYPEDEFINITION = 0x80C80000

    /* One of the references to follow in the relative path references to a node in the address space in another server. */
    case UA_STATUSCODE_UNCERTAINREFERENCEOUTOFSERVER = 0x406C0000

    /* The requested operation has too many matches to return. */
    case UA_STATUSCODE_BADTOOMANYMATCHES = 0x806D0000

    /* The requested operation requires too many resources in the server. */
    case UA_STATUSCODE_BADQUERYTOOCOMPLEX = 0x806E0000

    /* The requested operation has no match to return. */
    case UA_STATUSCODE_BADNOMATCH = 0x806F0000

    /* The max age parameter is invalid. */
    case UA_STATUSCODE_BADMAXAGEINVALID = 0x80700000

    /* The operation is not permitted over the current secure channel. */
    case UA_STATUSCODE_BADSECURITYMODEINSUFFICIENT = 0x80E60000

    /* The history details parameter is not valid. */
    case UA_STATUSCODE_BADHISTORYOPERATIONINVALID = 0x80710000

    /* The server does not support the requested operation. */
    case UA_STATUSCODE_BADHISTORYOPERATIONUNSUPPORTED = 0x80720000

    /* The defined timestamp to return was invalid. */
    case UA_STATUSCODE_BADINVALIDTIMESTAMPARGUMENT = 0x80BD0000

    /* The server does not support writing the combination of value */
    case UA_STATUSCODE_BADWRITENOTSUPPORTED = 0x80730000

    /* The value supplied for the attribute is not of the same type as the attribute's value. */
    case UA_STATUSCODE_BADTYPEMISMATCH = 0x80740000

    /* The method id does not refer to a method for the specified object. */
    case UA_STATUSCODE_BADMETHODINVALID = 0x80750000

    /* The client did not specify all of the input arguments for the method. */
    case UA_STATUSCODE_BADARGUMENTSMISSING = 0x80760000

    /* The executable attribute does not allow the execution of the method. */
    case UA_STATUSCODE_BADNOTEXECUTABLE = 0x81110000

    /* The server has reached its maximum number of subscriptions. */
    case UA_STATUSCODE_BADTOOMANYSUBSCRIPTIONS = 0x80770000

    /* The server has reached the maximum number of queued publish requests. */
    case UA_STATUSCODE_BADTOOMANYPUBLISHREQUESTS = 0x80780000

    /* There is no subscription available for this session. */
    case UA_STATUSCODE_BADNOSUBSCRIPTION = 0x80790000

    /* The sequence number is unknown to the server. */
    case UA_STATUSCODE_BADSEQUENCENUMBERUNKNOWN = 0x807A0000

    /* The requested notification message is no longer available. */
    case UA_STATUSCODE_BADMESSAGENOTAVAILABLE = 0x807B0000

    /* The client of the current session does not support one or more Profiles that are necessary for the subscription. */
    case UA_STATUSCODE_BADINSUFFICIENTCLIENTPROFILE = 0x807C0000

    /* The sub-state machine is not currently active. */
    case UA_STATUSCODE_BADSTATENOTACTIVE = 0x80BF0000

    /* An equivalent rule already exists. */
    case UA_STATUSCODE_BADALREADYEXISTS = 0x81150000

    /* The server cannot process the request because it is too busy. */
    case UA_STATUSCODE_BADTCPSERVERTOOBUSY = 0x807D0000

    /* The type of the message specified in the header invalid. */
    case UA_STATUSCODE_BADTCPMESSAGETYPEINVALID = 0x807E0000

    /* The SecureChannelId and/or TokenId are not currently in use. */
    case UA_STATUSCODE_BADTCPSECURECHANNELUNKNOWN = 0x807F0000

    /* The size of the message specified in the header is too large. */
    case UA_STATUSCODE_BADTCPMESSAGETOOLARGE = 0x80800000

    /* There are not enough resources to process the request. */
    case UA_STATUSCODE_BADTCPNOTENOUGHRESOURCES = 0x80810000

    /* An internal error occurred. */
    case UA_STATUSCODE_BADTCPINTERNALERROR = 0x80820000

    /* The server does not recognize the QueryString specified. */
    case UA_STATUSCODE_BADTCPENDPOINTURLINVALID = 0x80830000

    /* The request could not be sent because of a network interruption. */
    case UA_STATUSCODE_BADREQUESTINTERRUPTED = 0x80840000

    /* Timeout occurred while processing the request. */
    case UA_STATUSCODE_BADREQUESTTIMEOUT = 0x80850000

    /* The secure channel has been closed. */
    case UA_STATUSCODE_BADSECURECHANNELCLOSED = 0x80860000

    /* The token has expired or is not recognized. */
    case UA_STATUSCODE_BADSECURECHANNELTOKENUNKNOWN = 0x80870000

    /* The sequence number is not valid. */
    case UA_STATUSCODE_BADSEQUENCENUMBERINVALID = 0x80880000

    /* The applications do not have compatible protocol versions. */
    case UA_STATUSCODE_BADPROTOCOLVERSIONUNSUPPORTED = 0x80BE0000

    /* There is a problem with the configuration that affects the usefulness of the value. */
    case UA_STATUSCODE_BADCONFIGURATIONERROR = 0x80890000

    /* The variable should receive its value from another variable */
    case UA_STATUSCODE_BADNOTCONNECTED = 0x808A0000

    /* There has been a failure in the device/data source that generates the value that has affected the value. */
    case UA_STATUSCODE_BADDEVICEFAILURE = 0x808B0000

    /* There has been a failure in the sensor from which the value is derived by the device/data source. */
    case UA_STATUSCODE_BADSENSORFAILURE = 0x808C0000

    /* The source of the data is not operational. */
    case UA_STATUSCODE_BADOUTOFSERVICE = 0x808D0000

    /* The deadband filter is not valid. */
    case UA_STATUSCODE_BADDEADBANDFILTERINVALID = 0x808E0000

    /* Communication to the data source has failed. The variable value is the last value that had a good quality. */
    case UA_STATUSCODE_UNCERTAINNOCOMMUNICATIONLASTUSABLEVALUE = 0x408F0000

    /* Whatever was updating this value has stopped doing so. */
    case UA_STATUSCODE_UNCERTAINLASTUSABLEVALUE = 0x40900000

    /* The value is an operational value that was manually overwritten. */
    case UA_STATUSCODE_UNCERTAINSUBSTITUTEVALUE = 0x40910000

    /* The value is an initial value for a variable that normally receives its value from another variable. */
    case UA_STATUSCODE_UNCERTAININITIALVALUE = 0x40920000

    /* The value is at one of the sensor limits. */
    case UA_STATUSCODE_UNCERTAINSENSORNOTACCURATE = 0x40930000

    /* The value is outside of the range of values defined for this parameter. */
    case UA_STATUSCODE_UNCERTAINENGINEERINGUNITSEXCEEDED = 0x40940000

    /* The value is derived from multiple sources and has less than the required number of Good sources. */
    case UA_STATUSCODE_UNCERTAINSUBNORMAL = 0x40950000

    /* The value has been overridden. */
    case UA_STATUSCODE_GOODLOCALOVERRIDE = 0x00960000

    /* This Condition refresh failed */
    case UA_STATUSCODE_BADREFRESHINPROGRESS = 0x80970000

    /* This condition has already been disabled. */
    case UA_STATUSCODE_BADCONDITIONALREADYDISABLED = 0x80980000

    /* This condition has already been enabled. */
    case UA_STATUSCODE_BADCONDITIONALREADYENABLED = 0x80CC0000

    /* Property not available */
    case UA_STATUSCODE_BADCONDITIONDISABLED = 0x80990000

    /* The specified event id is not recognized. */
    case UA_STATUSCODE_BADEVENTIDUNKNOWN = 0x809A0000

    /* The event cannot be acknowledged. */
    case UA_STATUSCODE_BADEVENTNOTACKNOWLEDGEABLE = 0x80BB0000

    /* The dialog condition is not active. */
    case UA_STATUSCODE_BADDIALOGNOTACTIVE = 0x80CD0000

    /* The response is not valid for the dialog. */
    case UA_STATUSCODE_BADDIALOGRESPONSEINVALID = 0x80CE0000

    /* The condition branch has already been acknowledged. */
    case UA_STATUSCODE_BADCONDITIONBRANCHALREADYACKED = 0x80CF0000

    /* The condition branch has already been confirmed. */
    case UA_STATUSCODE_BADCONDITIONBRANCHALREADYCONFIRMED = 0x80D00000

    /* The condition has already been shelved. */
    case UA_STATUSCODE_BADCONDITIONALREADYSHELVED = 0x80D10000

    /* The condition is not currently shelved. */
    case UA_STATUSCODE_BADCONDITIONNOTSHELVED = 0x80D20000

    /* The shelving time not within an acceptable range. */
    case UA_STATUSCODE_BADSHELVINGTIMEOUTOFRANGE = 0x80D30000

    /* No data exists for the requested time range or event filter. */
    case UA_STATUSCODE_BADNODATA = 0x809B0000

    /* No data found to provide upper or lower bound value. */
    case UA_STATUSCODE_BADBOUNDNOTFOUND = 0x80D70000

    /* The server cannot retrieve a bound for the variable. */
    case UA_STATUSCODE_BADBOUNDNOTSUPPORTED = 0x80D80000

    /* Data is missing due to collection started/stopped/lost. */
    case UA_STATUSCODE_BADDATALOST = 0x809D0000

    /* Expected data is unavailable for the requested time range due to an un-mounted volume */
    case UA_STATUSCODE_BADDATAUNAVAILABLE = 0x809E0000

    /* The data or event was not successfully inserted because a matching entry exists. */
    case UA_STATUSCODE_BADENTRYEXISTS = 0x809F0000

    /* The data or event was not successfully updated because no matching entry exists. */
    case UA_STATUSCODE_BADNOENTRYEXISTS = 0x80A00000

    /* The client requested history using a timestamp format the server does not support (i.e requested ServerTimestamp when server only supports SourceTimestamp). */
    case UA_STATUSCODE_BADTIMESTAMPNOTSUPPORTED = 0x80A10000

    /* The data or event was successfully inserted into the historical database. */
    case UA_STATUSCODE_GOODENTRYINSERTED = 0x00A20000

    /* The data or event field was successfully replaced in the historical database. */
    case UA_STATUSCODE_GOODENTRYREPLACED = 0x00A30000

    /* The value is derived from multiple values and has less than the required number of Good values. */
    case UA_STATUSCODE_UNCERTAINDATASUBNORMAL = 0x40A40000

    /* No data exists for the requested time range or event filter. */
    case UA_STATUSCODE_GOODNODATA = 0x00A50000

    /* The data or event field was successfully replaced in the historical database. */
    case UA_STATUSCODE_GOODMOREDATA = 0x00A60000

    /* The requested number of Aggregates does not match the requested number of NodeIds. */
    case UA_STATUSCODE_BADAGGREGATELISTMISMATCH = 0x80D40000

    /* The requested Aggregate is not support by the server. */
    case UA_STATUSCODE_BADAGGREGATENOTSUPPORTED = 0x80D50000

    /* The aggregate value could not be derived due to invalid data inputs. */
    case UA_STATUSCODE_BADAGGREGATEINVALIDINPUTS = 0x80D60000

    /* The aggregate configuration is not valid for specified node. */
    case UA_STATUSCODE_BADAGGREGATECONFIGURATIONREJECTED = 0x80DA0000

    /* The request specifies fields which are not valid for the EventType or cannot be saved by the historian. */
    case UA_STATUSCODE_GOODDATAIGNORED = 0x00D90000

    /* The request was rejected by the server because it did not meet the criteria set by the server. */
    case UA_STATUSCODE_BADREQUESTNOTALLOWED = 0x80E40000

    /* The request has not been processed by the server yet. */
    case UA_STATUSCODE_BADREQUESTNOTCOMPLETE = 0x81130000

    /* The value does not come from the real source and has been edited by the server. */
    case UA_STATUSCODE_GOODEDITED = 0x00DC0000

    /* There was an error in execution of these post-actions. */
    case UA_STATUSCODE_GOODPOSTACTIONFAILED = 0x00DD0000

    /* The related EngineeringUnit has been changed but the Variable Value is still provided based on the previous unit. */
    case UA_STATUSCODE_UNCERTAINDOMINANTVALUECHANGED = 0x40DE0000

    /* A dependent value has been changed but the change has not been applied to the device. */
    case UA_STATUSCODE_GOODDEPENDENTVALUECHANGED = 0x00E00000

    /* The related EngineeringUnit has been changed but this change has not been applied to the device. The Variable Value is still dependent on the previous unit but its status is currently Bad. */
    case UA_STATUSCODE_BADDOMINANTVALUECHANGED = 0x80E10000

    /* A dependent value has been changed but the change has not been applied to the device. The quality of the dominant variable is uncertain. */
    case UA_STATUSCODE_UNCERTAINDEPENDENTVALUECHANGED = 0x40E20000

    /* A dependent value has been changed but the change has not been applied to the device. The quality of the dominant variable is Bad. */
    case UA_STATUSCODE_BADDEPENDENTVALUECHANGED = 0x80E30000

    /* The communication layer has raised an event. */
    case UA_STATUSCODE_GOODCOMMUNICATIONEVENT = 0x00A70000

    /* The system is shutting down. */
    case UA_STATUSCODE_GOODSHUTDOWNEVENT = 0x00A80000

    /* The operation is not finished and needs to be called again. */
    case UA_STATUSCODE_GOODCALLAGAIN = 0x00A90000

    /* A non-critical timeout occurred. */
    case UA_STATUSCODE_GOODNONCRITICALTIMEOUT = 0x00AA0000

    /* One or more arguments are invalid. */
    case UA_STATUSCODE_BADINVALIDARGUMENT = 0x80AB0000

    /* Could not establish a network connection to remote server. */
    case UA_STATUSCODE_BADCONNECTIONREJECTED = 0x80AC0000

    /* The server has disconnected from the client. */
    case UA_STATUSCODE_BADDISCONNECT = 0x80AD0000

    /* The network connection has been closed. */
    case UA_STATUSCODE_BADCONNECTIONCLOSED = 0x80AE0000

    /* The operation cannot be completed because the object is closed */
    case UA_STATUSCODE_BADINVALIDSTATE = 0x80AF0000

    /* Cannot move beyond end of the stream. */
    case UA_STATUSCODE_BADENDOFSTREAM = 0x80B00000

    /* No data is currently available for reading from a non-blocking stream. */
    case UA_STATUSCODE_BADNODATAAVAILABLE = 0x80B10000

    /* The asynchronous operation is waiting for a response. */
    case UA_STATUSCODE_BADWAITINGFORRESPONSE = 0x80B20000

    /* The asynchronous operation was abandoned by the caller. */
    case UA_STATUSCODE_BADOPERATIONABANDONED = 0x80B30000

    /* The stream did not return all data requested (possibly because it is a non-blocking stream). */
    case UA_STATUSCODE_BADEXPECTEDSTREAMTOBLOCK = 0x80B40000

    /* Non blocking behaviour is required and the operation would block. */
    case UA_STATUSCODE_BADWOULDBLOCK = 0x80B50000

    /* A value had an invalid syntax. */
    case UA_STATUSCODE_BADSYNTAXERROR = 0x80B60000

    /* The operation could not be finished because all available connections are in use. */
    case UA_STATUSCODE_BADMAXCONNECTIONSREACHED = 0x80B70000
}
