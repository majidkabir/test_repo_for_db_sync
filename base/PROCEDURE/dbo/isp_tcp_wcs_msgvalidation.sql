SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: isp_TCP_WCS_MsgValidation                           */  
/* Creation Date: 15 Jan 2014                                           */  
/* Copyright: LFL                                                       */  
/* Written by: TKLIM                                                    */  
/*                                                                      */  
/* Purpose: 1) Validate all message length and data (message mapping)   */  
/*          2) Construct respond message (Success or Fail)              */  
/*          3) Query TCPSocket_Process table for Generic StorProc based */  
/*             on ProjectName and MessageName                           */  
/*          4) Return MessageNum, SprocName, Status,RespondMsg & ErrMsg */  
/*                                                                      */  
/* Called By: TCPSocket_Listenner                                       */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 1.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Date         Author    Ver.  Purposes                                */  
/* 09-Mar-2015  TKLIM     1.0   Temporary Map WCS-WMS Loc (TK01)        */  
/* 02-Nov-2015  TKLIM     1.1   Remove FromLoc validation for SHUFFLE   */  
/* 27-Jan-2015  TKLIM     1.2   Add validation on Duplicate Conf Msg    */  
/* 18-May-2017  BARNETT   1.0   Add New MessageName 'REQ4PUTAWAY'       */  
/************************************************************************/  
  
CREATE PROCEDURE [dbo].[isp_TCP_WCS_MsgValidation] (  
     @n_SerialNo        INT      
    ,@b_Debug           INT      
    ,@c_MessageNum      NVARCHAR(10)   OUTPUT  
    ,@c_SprocName       NVARCHAR(30)   OUTPUT  
    ,@c_Status          NVARCHAR(1)    OUTPUT  
    ,@c_RespondMsg      NVARCHAR(500)  OUTPUT  
    ,@b_Success         INT            OUTPUT  
    ,@n_Err             INT            OUTPUT  
    ,@c_ErrMsg          NVARCHAR(250)  OUTPUT  
 )  
AS   
BEGIN   
   SET NOCOUNT ON  
   SET ANSI_DEFAULTS OFF    
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF    
  
   /*********************************************/  
   /* Variables Declaration                     */  
   /*********************************************/  
   DECLARE @c_ExecStatements  NVARCHAR(4000)       
         , @c_ExecArguments   NVARCHAR(4000)   
         , @n_continue        INT                  
     
   DECLARE @c_AckMessageID    NVARCHAR(10)     
         , @c_MessageName     NVARCHAR(15)   --'PUTAWAY', 'MOVE', 'TSKUPD'  etc....  
         , @c_MessageType     NVARCHAR(10)   --'SEND', 'RECEIVE'  
         , @c_WCSMessageID    NVARCHAR(10)   
         , @c_OrigMessageID   NVARCHAR(10)   
         , @c_PalletID        NVARCHAR(18)   
         , @c_FromLoc         NVARCHAR(10)   
         , @c_ToLoc           NVARCHAR(10)   
         , @c_OnConveyor      NVARCHAR(1)    --for 'INVQUERY' message  
         , @c_Priority        NVARCHAR(1)    --for 'MOVE' and 'TSKUPD' message  
         , @c_MsgStatus       NVARCHAR(10)   --for responce from WCS  
         , @c_MsgReasonCode   NVARCHAR(10)   --for responce from WCS  
         , @c_MsgErrMsg       NVARCHAR(100)  --for responce from WCS  
         , @c_UD1             NVARCHAR(20)   --PhotoReq / TaskUpdCode / MotherPltEmpty / PrintID / ToPallet  
         , @c_UD2             NVARCHAR(20)   --LabelReq / Weight  
         , @c_UD3             NVARCHAR(20)   --Storer / Height  
         , @c_UD4             NVARCHAR(20)   
         , @c_UD5             NVARCHAR(20)   
         , @c_ImgFolderPath   NVARCHAR(100)  --Image WCS Path  
         , @c_ImgFilename1    NVARCHAR(60)   --Image Filename1  
         , @c_ImgFilename2    NVARCHAR(60)   --Image Filename2  
         , @c_ImgFilename3    NVARCHAR(60)   --Image Filename3  
         , @c_ImgFilename4    NVARCHAR(60)   --Image Filename4  
         , @c_ImgFilename5    NVARCHAR(60)   --Image Filename5  
         , @c_Param1          NVARCHAR(20)   --PAway_SKU1  / EPS_Pallet1   
         , @c_Param2          NVARCHAR(20)   --PAway_SKU2  / EPS_Pallet2   
         , @c_Param3          NVARCHAR(20)   --PAway_SKU3  / EPS_Pallet3   
         , @c_Param4          NVARCHAR(20)   --PAway_SKU4  / EPS_Pallet4   
         , @c_Param5          NVARCHAR(20)   --PAway_SKU5  / EPS_Pallet5   
         , @c_Param6          NVARCHAR(20)   --PAway_SKU6  / EPS_Pallet6   
         , @c_Param7          NVARCHAR(20)   --PAway_SKU7  / EPS_Pallet7   
         , @c_Param8          NVARCHAR(20)   --PAway_SKU8  / EPS_Pallet8   
         , @c_Param9          NVARCHAR(20)   --PAway_SKU9  / EPS_Pallet9   
         , @c_Param10         NVARCHAR(20)   --PAway_SKU10 / EPS_Pallet10  
         , @c_Param11         NVARCHAR(20)   --PAway_SKU11   
         , @c_Param12         NVARCHAR(20)   --PAway_SKU12   
         , @c_Param13         NVARCHAR(20)   --PAway_SKU13   
         , @c_Param14         NVARCHAR(20)   --PAway_SKU14   
         , @c_Param15         NVARCHAR(20)   --PAway_SKU15   
         , @c_Param16         NVARCHAR(20)   --PAway_SKU16    
         , @c_Param17         NVARCHAR(20)   --PAway_SKU17    
         , @c_Param18         NVARCHAR(20)   --PAway_SKU18    
         , @c_Param19         NVARCHAR(20)   --PAway_SKU19    
         , @c_Param20         NVARCHAR(20)   --PAway_SKU20   
         , @c_Param21         NVARCHAR(20)   --PAway_SKU21  
         , @c_Param22         NVARCHAR(20)   --PAway_SKU22  
         , @c_Param23         NVARCHAR(20)   --PAway_SKU23  
         , @c_Param24         NVARCHAR(20)   --PAway_SKU24  
         , @c_Param25         NVARCHAR(20)   --PAway_SKU25  
         , @c_Param26         NVARCHAR(20)   --PAway_SKU26  
         , @c_Param27         NVARCHAR(20)   --PAway_SKU27  
         , @c_Param28         NVARCHAR(20)   --PAway_SKU28  
         , @c_Param29         NVARCHAR(20)   --PAway_SKU29  
         , @c_Param30         NVARCHAR(20)   --PAway_SKU30  
         , @c_Param31         NVARCHAR(20)   --PAway_SKU31  
         , @c_Param32         NVARCHAR(20)   --PAway_SKU32  
         , @c_Param33         NVARCHAR(20)   --PAway_SKU33  
         , @c_Param34         NVARCHAR(20)   --PAway_SKU34  
         , @c_Param35         NVARCHAR(20)   --PAway_SKU35  
         , @c_Param36         NVARCHAR(20)   --PAway_SKU36  
         , @c_Param37         NVARCHAR(20)   --PAway_SKU37  
         , @c_Param38         NVARCHAR(20)   --PAway_SKU38  
         , @c_Param39         NVARCHAR(20)   --PAway_SKU39  
         , @c_Param40         NVARCHAR(20)   --PAway_SKU40  
         , @c_Param41         NVARCHAR(20)   --PAway_SKU41  
         , @c_Param42         NVARCHAR(20)   --PAway_SKU42  
         , @c_Param43         NVARCHAR(20)   --PAway_SKU43  
         , @c_Param44         NVARCHAR(20)   --PAway_SKU44  
         , @c_Param45         NVARCHAR(20)   --PAway_SKU45  
         , @c_Param46         NVARCHAR(20)   --PAway_SKU46  
         , @c_Param47         NVARCHAR(20)   --PAway_SKU47  
         , @c_Param48         NVARCHAR(20)   --PAway_SKU48  
         , @c_Param49         NVARCHAR(20)   --PAway_SKU49  
         , @c_Param50         NVARCHAR(20)   --PAway_SKU50  
         , @c_Param51         NVARCHAR(20)   --PAway_SKU51  
         , @c_Param52         NVARCHAR(20)   --PAway_SKU52  
         , @c_Param53         NVARCHAR(20)   --PAway_SKU53  
         , @c_Param54         NVARCHAR(20)   --PAway_SKU54  
         , @c_Param55         NVARCHAR(20)   --PAway_SKU55  
         , @c_Param56         NVARCHAR(20)   --PAway_SKU56  
         , @c_Param57         NVARCHAR(20)   --PAway_SKU57  
         , @c_Param58         NVARCHAR(20)   --PAway_SKU58  
         , @c_Param59         NVARCHAR(20)   --PAway_SKU59  
  , @c_Param60         NVARCHAR(20)   --PAway_SKU60  
         , @c_Param61         NVARCHAR(20)   --PAway_SKU61  
         , @c_Param62         NVARCHAR(20)   --PAway_SKU62  
         , @c_Param63         NVARCHAR(20)   --PAway_SKU63  
         , @c_Param64         NVARCHAR(20)   --PAway_SKU64  
         , @c_Param65         NVARCHAR(20)   --PAway_SKU65  
         , @c_Param66         NVARCHAR(20)   --PAway_SKU66  
         , @c_Param67         NVARCHAR(20)   --PAway_SKU67  
         , @c_Param68         NVARCHAR(20)   --PAway_SKU68  
         , @c_Param69         NVARCHAR(20)   --PAway_SKU69  
         , @c_Param70         NVARCHAR(20)   --PAway_SKU70  
         , @c_Param71         NVARCHAR(20)   --PAway_SKU71  
         , @c_Param72         NVARCHAR(20)   --PAway_SKU72  
         , @c_Param73         NVARCHAR(20)   --PAway_SKU73  
         , @c_Param74         NVARCHAR(20)   --PAway_SKU74  
         , @c_Param75         NVARCHAR(20)   --PAway_SKU75  
         , @c_Param76         NVARCHAR(20)   --PAway_SKU76  
         , @c_Param77         NVARCHAR(20)   --PAway_SKU77  
         , @c_Param78         NVARCHAR(20)   --PAway_SKU78  
         , @c_Param79         NVARCHAR(20)   --PAway_SKU79  
         , @c_Param80         NVARCHAR(20)   --PAway_SKU80  
         , @c_Param81         NVARCHAR(20)   --PAway_SKU81  
         , @c_Param82         NVARCHAR(20)   --PAway_SKU82  
         , @c_Param83         NVARCHAR(20)   --PAway_SKU83  
         , @c_Param84         NVARCHAR(20)   --PAway_SKU84  
         , @c_Param85         NVARCHAR(20)   --PAway_SKU85  
         , @c_Param86         NVARCHAR(20)   --PAway_SKU86  
         , @c_Param87         NVARCHAR(20)   --PAway_SKU87  
         , @c_Param88         NVARCHAR(20)   --PAway_SKU88  
         , @c_Param89         NVARCHAR(20)   --PAway_SKU89  
         , @c_Param90         NVARCHAR(20)   --PAway_SKU90  
         , @c_Param91         NVARCHAR(20)   --PAway_SKU91  
         , @c_Param92         NVARCHAR(20)   --PAway_SKU92  
         , @c_Param93         NVARCHAR(20)   --PAway_SKU93  
         , @c_Param94         NVARCHAR(20)   --PAway_SKU94  
         , @c_Param95         NVARCHAR(20)   --PAway_SKU95  
         , @c_Param96         NVARCHAR(20)   --PAway_SKU96  
         , @c_Param97         NVARCHAR(20)   --PAway_SKU97  
         , @c_Param98         NVARCHAR(20)   --PAway_SKU98  
         , @c_Param99         NVARCHAR(20)   --PAway_SKU99  
         , @c_Param100        NVARCHAR(20)   --PAway_SKU100  
  
   DECLARE @c_StorerKey       NVARCHAR(15)  
         , @c_MessageGroup    NVARCHAR(20)  
         , @c_ReasonCode      NVARCHAR(10)  
         , @c_TmpAllImg       NVARCHAR(4000) --Temp string to store looping value (SKU / ImageFileName)  
         , @c_TmpFilename     NVARCHAR(60)   --Temp Filename  
         , @n_Count           INT  
  
   DECLARE @c_MapWCSLoc          NVARCHAR(1)    --(TK01) translate WCS Location to WMS Location  
         , @c_WCSToLoc           NVARCHAR(10)   --(TK01)  
         , @c_WCSFromLoc         NVARCHAR(10)   --(TK01)  
         , @n_NoOfImage          INT            --(TK02)  
         , @c_PrevWCSMessageID   NVARCHAR(10)   --(TK03)  
  
   SET @c_MessageNum             = CAST(@n_SerialNo AS VARCHAR(10))  
   SET @c_OrigMessageID          = ''  
   SET @c_PrevWCSMessageID       = ''  --(TK03)  
   SET @c_SProcName              = ''  
   SET @c_Status                 = '9'  
   SET @c_RespondMsg             = ''  
   SET @b_Success                = 1  
   SET @n_Err                    = 0  
   SET @c_ErrMsg                 = ''  
  
   SET @c_ExecStatements         = ''   
   SET @c_ExecArguments          = ''  
   SET @n_continue               = 1   
   SET @c_StorerKey              = ''  
   SET @c_MessageGroup           = 'WCS'  
   SET @c_MessageType            = 'RECEIVE'  
  
   SET @c_MapWCSLoc              = '1'    --(TK01)  
   SET @n_NoOfImage              = 0  
  
   /*********************************************/  
   /* Query value from message - START          */  
   /*********************************************/  
  
   IF @n_Continue = 1 OR @n_Continue = 2  
   BEGIN  
  
      SELECT @c_WCSMessageID     = SUBSTRING(Data,  1,  10)  
            ,@c_MessageName      = SUBSTRING(Data, 11,  15)  
      FROM TCPSOCKET_INLOG WITH (NOLOCK)  
      WHERE SerialNo = @n_SerialNo  
  
      IF RTRIM(@c_MessageName) = 'PUTAWAY'  
      BEGIN  
         SELECT @c_OrigMessageID    = SUBSTRING(Data, 26,  10)  
               ,@c_PalletID         = SUBSTRING(Data, 36,  18)  
               ,@c_ToLoc            = SUBSTRING(Data, 54,  10)  
               ,@c_MsgStatus        = SUBSTRING(Data, 64,  10)  
               ,@c_MsgReasonCode    = SUBSTRING(Data, 74,  10)  
               ,@c_MsgErrMsg        = SUBSTRING(Data, 84, 100)  
         FROM TCPSOCKET_INLOG WITH (NOLOCK)  
         WHERE SerialNo = @n_SerialNo  
  
      END  
      ELSE IF RTRIM(@c_MessageName) = 'MOVE'  
      BEGIN  
         SELECT @c_OrigMessageID    = SUBSTRING(Data, 26,  10)  
               ,@c_PalletID         = SUBSTRING(Data, 36,  18)  
               ,@c_FromLoc          = SUBSTRING(Data, 54,  10)  
               ,@c_ToLoc            = SUBSTRING(Data, 64,  10)  
               ,@c_MsgStatus        = SUBSTRING(Data, 74,  10)  
               ,@c_MsgReasonCode    = SUBSTRING(Data, 84,  10)  
               ,@c_MsgErrMsg        = SUBSTRING(Data, 94, 100)  
         FROM TCPSOCKET_INLOG WITH (NOLOCK)  
         WHERE SerialNo = @n_SerialNo  
  
      END  
      ELSE IF RTRIM(@c_MessageName) = 'TASKUPDATE'  
      BEGIN  
         SELECT @c_OrigMessageID    = SUBSTRING(Data, 26,  10)  
               ,@c_PalletID         = SUBSTRING(Data, 36,  18)  
               ,@c_MsgStatus        = SUBSTRING(Data, 54,  10)  
               ,@c_MsgReasonCode    = SUBSTRING(Data, 64,  10)  
               ,@c_MsgErrMsg        = SUBSTRING(Data, 74, 100)  
         FROM TCPSOCKET_INLOG WITH (NOLOCK)  
         WHERE SerialNo = @n_SerialNo  
  
      END  
      ELSE IF RTRIM(@c_MessageName) = 'INVQUERY'  
      BEGIN  
         SELECT @c_OrigMessageID    = SUBSTRING(Data, 26,  10)  
               ,@c_PalletID         = SUBSTRING(Data, 36,  18)  
               ,@c_ToLoc            = SUBSTRING(Data, 54,  10)  
               ,@c_OnConveyor       = SUBSTRING(Data, 64,   1)  
               ,@c_MsgStatus        = SUBSTRING(Data, 65,  10)  
               ,@c_MsgReasonCode    = SUBSTRING(Data, 75,  10)  
               ,@c_MsgErrMsg        = SUBSTRING(Data, 85, 100)  
         FROM TCPSOCKET_INLOG WITH (NOLOCK)  
         WHERE SerialNo = @n_SerialNo  
  
      END  
      ELSE IF RTRIM(@c_MessageName) = 'PLTSWAP'  
      BEGIN  
         SELECT @c_OrigMessageID    = SUBSTRING(Data, 26,  10)  
               ,@c_PalletID         = SUBSTRING(Data, 36,  18)    --FromPalletID  
               ,@c_UD1              = SUBSTRING(Data, 54,  18)    --ToPalletID  
               ,@c_MsgStatus        = SUBSTRING(Data, 72,  10)  
               ,@c_MsgReasonCode    = SUBSTRING(Data, 82,  10)  
               ,@c_MsgErrMsg        = SUBSTRING(Data, 92, 100)  
         FROM TCPSOCKET_INLOG WITH (NOLOCK)             
         WHERE SerialNo = @n_SerialNo  
  
      END  
      ELSE IF RTRIM(@c_MessageName) = 'EPS'  
      BEGIN  
         SELECT @c_PalletID         = SUBSTRING(Data,  26,  18)    --MotherPltID          26 50265428########## 18  
               ,@c_Param1           = SUBSTRING(Data,  44,  18)    --EPS_Pallet1          44 0#502476########## 18  
               ,@c_Param2           = SUBSTRING(Data,  62,  18)    --EPS_Pallet2          62 08120036########## 18  
               ,@c_Param3           = SUBSTRING(Data,  80,  18)    --EPS_Pallet3          80 48120918########## 18  
               ,@c_Param4           = SUBSTRING(Data,  98,  18)    --EPS_Pallet4          98 98300763########## 18  
               ,@c_Param5           = SUBSTRING(Data, 116,  18)    --EPS_Pallet5         116 72502301########## 18  
               ,@c_Param6           = SUBSTRING(Data, 134,  18)    --EPS_Pallet6 134 05121476########## 18  
               ,@c_Param7           = SUBSTRING(Data, 152,  18)    --EPS_Pallet7         152 63220743########## 18  
               ,@c_Param8           = SUBSTRING(Data, 170,  18)    --EPS_Pallet8         170 55502124########## 18  
               ,@c_Param9           = SUBSTRING(Data, 188,  18)    --EPS_Pallet9         188 15121747########## 18  
               ,@c_Param10          = SUBSTRING(Data, 206,  18)    --EPS_Pallet10        206 ################## 18  
         FROM TCPSOCKET_INLOG WITH (NOLOCK)  
         WHERE SerialNo = @n_SerialNo  
  
      END  
      ELSE IF RTRIM(@c_MessageName) = 'PRINTLABEL'  
      BEGIN  
         SELECT @c_PalletID         = SUBSTRING(Data, 26,  18)  
               ,@c_UD1              = SUBSTRING(Data, 44,  10)    --PrinterID  
               ,@c_UD2              = SUBSTRING(Data, 54,  10)    --Weight  
               ,@c_UD3              = SUBSTRING(Data, 64,  10)    --Height  
         FROM TCPSOCKET_INLOG WITH (NOLOCK)  
         WHERE SerialNo = @n_SerialNo  
  
      END  
      ELSE IF RTRIM(@c_MessageName) = 'SHUFFLE'  
      BEGIN  
         SELECT @c_PalletID         = SUBSTRING(Data, 26,  18)  
               ,@c_FromLoc          = SUBSTRING(Data, 44,  10)  
               ,@c_ToLoc            = SUBSTRING(Data, 54,  10)  
         FROM TCPSOCKET_INLOG WITH (NOLOCK)  
         WHERE SerialNo = @n_SerialNo  
  
      END  
      ELSE IF RTRIM(@c_MessageName) = 'PHOTO'  
      BEGIN  
         SELECT @c_PalletID         = SUBSTRING(Data,  26,   18)  
               ,@c_UD1              = SUBSTRING(Data,  44,   14)    --TimeStamp  
               ,@c_UD2              = SUBSTRING(Data,  58,    2)    --NoOfImage  
               ,@c_ImgFolderPath    = SUBSTRING(Data,  60,  100)    --Path  
               ,@c_TmpAllImg        = SUBSTRING(Data, 160, 4000)    --ImgFilename  
         FROM TCPSOCKET_INLOG WITH (NOLOCK)  
         WHERE SerialNo = @n_SerialNo  
  
         IF ISNUMERIC(ISNULL(RTRIM(@c_UD2),0)) = 1  
         BEGIN  
            SET @n_NoOfImage = CONVERT(INT,ISNULL(RTRIM(@c_UD2),0))  
  
            IF @n_NoOfImage >= 1 SET @c_ImgFileName1 = ISNULL(RTRIM(SUBSTRING(@c_TmpAllImg,   1, 60)),'')  
            IF @n_NoOfImage >= 2 SET @c_ImgFileName2 = ISNULL(RTRIM(SUBSTRING(@c_TmpAllImg,  61, 60)),'')  
            IF @n_NoOfImage >= 3 SET @c_ImgFileName3 = ISNULL(RTRIM(SUBSTRING(@c_TmpAllImg, 121, 60)),'')  
            IF @n_NoOfImage >= 4 SET @c_ImgFileName4 = ISNULL(RTRIM(SUBSTRING(@c_TmpAllImg, 181, 60)),'')  
            IF @n_NoOfImage >= 5 SET @c_ImgFileName5 = ISNULL(RTRIM(SUBSTRING(@c_TmpAllImg, 241, 60)),'')  
         END  
  
      END  
      ELSE IF RTRIM(@c_MessageName) = 'HEARTBEAT'  
      BEGIN  
         --Do nothing, Respond ACK  
         SET @c_PalletID = ''  
         SET @c_Status = '9'  
         SET @c_ReasonCode = ''  
         SET @c_ErrMsg = ''  
         GOTO SEND_RESPOND  
      END  
      ELSE IF RTRIM(@c_MessageName) = 'REQ4PUTAWAY'  
      BEGIN  
  
         SELECT @c_PalletID         = SUBSTRING(Data, 26,  18)  
              , @c_FromLoc          = SUBSTRING(Data, 44,  10)                                                         
         FROM TCPSOCKET_INLOG WITH (NOLOCK)  
         WHERE SerialNo = @n_SerialNo  
                                                                                                                         
      END  
      ELSE   
      BEGIN  
         SET @n_Continue = 3  
         SET @c_Status = '5'  
         SET @c_ReasonCode = 'F04'  
         SET @c_ErrMsg = 'Invalid Message Name (' + RTRIM(@c_MessageName) + ').'  
         GOTO SEND_RESPOND  
      END  
  
      --(TK03) - Add checking to prevent processing duplicate Confirmation message from WCS  
      IF ISNULL(RTRIM(@c_OrigMessageID),'') <> ''  
      BEGIN   
  
         SELECT @c_PrevWCSMessageID = ISNULL(RTRIM(WCSMessageID),'')  
         FROM WCSTran (NOLOCK)   
         WHERE MessageName    = @c_MessageName  
         AND   MessageType    = @c_MessageType  
         AND   OrigMessageID  = @c_OrigMessageID  
         AND   PalletID       = @c_PalletID  
         AND   Status         = '9'  
  
         IF @c_PrevWCSMessageID <> ''  
         BEGIN  
            --SET @n_Continue = 3  
            SET @c_Status = '5'  
            SET @c_ReasonCode = 'F98'  
            SET @c_ErrMsg = 'Duplicate message from WCS. (MessageID: ' + RTRIM(@c_OrigMessageID) + ').'  
            GOTO SEND_RESPOND  
         END  
  
      END  
   END  
  
   /*********************************************/  
   /* Query value from message - END            */  
   /*********************************************/  
   /*********************************************/  
   /* Insert RECEIVE Message into WCSTran      */  
   /*********************************************/  
   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN  
      INSERT INTO WCSTran    
                  ( MessageNum, MessageName, MessageType, WCSMessageID, OrigMessageID, PalletID   
                  , FromLoc, ToLoc, Priority, Status, ReasonCode, ErrMsg   
                  , UD1, UD2, UD3, UD4, UD5   
                  , ImgFolderPath, ImgFileName1, ImgFileName2, ImgFileName3, ImgFileName4, ImgFileName5  
                  , Param1,  Param2,  Param3,  Param4,  Param5,  Param6,  Param7,  Param8,  Param9,  Param10)  
      VALUES      ( @c_MessageNum, @c_MessageName, @c_MessageType, @c_WCSMessageID, @c_OrigMessageID, @c_PalletID   
                  , @c_FromLoc, @c_ToLoc, @c_Priority, @c_Status, @c_ReasonCode, @c_ErrMsg   
                  , @c_UD1, @c_UD2, @c_UD3, @c_UD4, @c_UD5   
                  , @c_ImgFolderPath, @c_ImgFileName1, @c_ImgFileName2, @c_ImgFileName3, @c_ImgFileName4, @c_ImgFileName5  
                  , @c_Param1,  @c_Param2,  @c_Param3,  @c_Param4,  @c_Param5,  @c_Param6,  @c_Param7,  @c_Param8,  @c_Param9,  @c_Param10)  
  
      IF @@ERROR <> 0  
      BEGIN  
         SET @n_continue = 3  
         SET @n_err=68004     
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))   
                        + ': Insert record into WCSTran fail. (isp_TCP_WCS_MsgValidation) ( '   
                        + ' sqlsvr message=' + ISNULL(RTRIM(@c_ErrMsg), '') + ' ) '  
         GOTO QUIT  
      END  
   END  
  
   /*********************************************/  
   /* General Validation - START                */  
   /*********************************************/  
   IF @n_Continue = 1 OR @n_Continue = 2  
   BEGIN  
  
      --(TK01) - Start  
      IF @c_MapWCSLoc = '1'  
      BEGIN  
         SET @c_WCSToLoc = @c_ToLoc  
         SET @c_WCSFromLoc = @c_FromLoc  
  
         SELECT @c_ToLoc = CASE WHEN ISNULL(RTRIM(Short),'') <> '' THEN Short END  
         FROM CODELKUP WITH (NOLOCK)  
         WHERE ListName = 'MAPWCS2WMS' AND Code = @c_WCSToLoc  
  
         SELECT @c_FromLoc = CASE WHEN ISNULL(RTRIM(Short),'') <> '' THEN Short END  
         FROM CODELKUP WITH (NOLOCK)  
         WHERE ListName = 'MAPWCS2WMS' AND Code = @c_WCSFromLoc  
  
      END  
      --(TK01) - END  
  
      IF RTRIM(@c_MessageName) <> ('PLTSWAP') AND CHARINDEX(' ', RTRIM(@c_PalletID)) <> 0   --PalletID  
      BEGIN  
         SET @c_Status = '5'  
         SET @c_ReasonCode = 'F05'  
         SET @c_ErrMsg = 'Invalid Pallet ID (' + RTRIM(@c_PalletID) + ').'  
         GOTO SEND_RESPOND  
      END  
  
      --IF RTRIM(@c_MessageName) IN ('')                                                     --Location ???  
      --BEGIN  
      --   IF NOT EXISTS (SELECT 1 FROM LOC WITH (NOLOCK) WHERE LOC = )  
      --   BEGIN  
      --      SET @n_Continue = 3  
      --      SET @c_Status = '5'  
      --      SET @c_ReasonCode = 'F08'  
      --      SET @c_ErrMsg = 'Invalid Location (' + RTRIM() + ').'  
      --      GOTO SEND_RESPOND  
      --   END  
      --END  
  
      --IF RTRIM(@c_MessageName) IN ('SHUFFLE')                                        --FromLoc  
      --BEGIN  
      --   IF RTRIM(@c_FromLoc) = '' OR NOT EXISTS (SELECT 1 FROM LOC WITH (NOLOCK) WHERE LOC = RTRIM(@c_FromLoc))  
      --   BEGIN  
      --      SET @c_Status = '5'  
      --      SET @c_ReasonCode = 'F09'  
      --      SET @c_ErrMsg = 'Invalid FromLocation (' + RTRIM(@c_FromLoc) + ').'  
      --      GOTO SEND_RESPOND  
      --   END  
      --END  
  
      IF RTRIM(@c_MessageName) IN ('PUTAWAY', 'MOVE', 'SHUFFLE', 'INVQUERY')                 --ToLoc  
      BEGIN  
         IF RTRIM(@c_ToLoc) = '' OR NOT EXISTS (SELECT 1 FROM LOC WITH (NOLOCK) WHERE LOC =  RTRIM(@c_ToLoc))  
         BEGIN  
            SET @c_Status = '5'  
            SET @c_ReasonCode = 'F10'  
            SET @c_ErrMsg = 'Invalid ToLocation (' + RTRIM(@c_ToLoc) + ').'  
            GOTO SEND_RESPOND  
         END  
      END  
  
      --IF RTRIM(@c_MessageName) IN ('PUTAWAY', 'MOVE', 'TASKUPDATE', 'INVQUERY', 'PLTSWAP')   --OrigMessageID  
      --BEGIN  
      --   IF RTRIM(@c_OrigMessageID) = '' OR NOT EXISTS (SELECT 1 FROM TCPSOCKET_INLOG WITH (NOLOCK) WHERE MessageNum =  RTRIM(@c_OrigMessageID) AND Status = '9')  
      --   BEGIN  
      --      SET @c_Status = '5'  
      --      SET @c_ReasonCode = 'F15'  
      --      SET @c_ErrMsg = 'Invalid OrigMessageID (' + RTRIM(@c_OrigMessageID) + ').'  
      --      GOTO SEND_RESPOND  
      --   END  
      --END  
   END  
   /*********************************************/  
   /* General Validation - END                  */  
   /*********************************************/  
  
  
   /*********************************************/  
   /* Message Specific Validation - START       */  
   /*********************************************/  
   IF @n_Continue = 1 OR @n_Continue = 2  
   BEGIN  
  
      IF RTRIM(@c_MessageName) = 'PLTSWAP'     
      BEGIN  
         IF RTRIM(@c_PalletID) = '' OR CHARINDEX(' ', RTRIM(@c_PalletID)) <> 0               --FromPalletID  
         BEGIN  
            SET @c_Status = '5'  
            SET @c_ReasonCode = 'F06'  
            SET @c_ErrMsg = 'Invalid FromPalletID (' + RTRIM(@c_PalletID) + ').'  
            GOTO SEND_RESPOND  
         END  
  
         IF RTRIM(@c_UD1) = '' OR CHARINDEX(' ', RTRIM(@c_UD1)) <> 0                         --FromPalletID  
         BEGIN  
            SET @c_Status = '5'  
            SET @c_ReasonCode = 'F07'  
            SET @c_ErrMsg = 'Invalid ToPalletID (' + RTRIM(@c_UD1) + ').'  
            GOTO SEND_RESPOND  
         END  
      END  
  
      IF RTRIM(@c_MessageName) = 'INVQUERY'                                                  --OnConveyor  
      BEGIN  
         IF RTRIM(@c_OnConveyor) = '' OR RTRIM(@c_OnConveyor) NOT IN ('Y', 'N')  
         BEGIN  
            SET @c_Status = '5'  
            SET @c_ReasonCode = 'F16'  
            SET @c_ErrMsg = 'Invalid OnConveyor Flag (' + RTRIM(@c_OnConveyor) + ').'  
            GOTO SEND_RESPOND  
         END  
      END  
  
      --Move Base validation to isp_TCP_WCS_MsgEPS so WMS can respond error via EPS Confirmation Message.                                             
      --IF RTRIM(@c_MessageName) = 'EPS'                                                       --EPS PalletID  
      --BEGIN  
  
      --   IF (RTRIM(@c_Param1 ) = '' OR CHARINDEX(' ', RTRIM(@c_Param1 )) <> 0) SET @c_ErrMsg = 'Invalid EPS PalletID (' + RTRIM(@c_Param1 ) + ').'  
      --   IF (RTRIM(@c_Param2 ) = '' OR CHARINDEX(' ', RTRIM(@c_Param2 )) <> 0) SET @c_ErrMsg = 'Invalid EPS PalletID (' + RTRIM(@c_Param2 ) + ').'  
      --   IF (RTRIM(@c_Param3 ) = '' OR CHARINDEX(' ', RTRIM(@c_Param3 )) <> 0) SET @c_ErrMsg = 'Invalid EPS PalletID (' + RTRIM(@c_Param3 ) + ').'  
      --   IF (RTRIM(@c_Param4 ) = '' OR CHARINDEX(' ', RTRIM(@c_Param4 )) <> 0) SET @c_ErrMsg = 'Invalid EPS PalletID (' + RTRIM(@c_Param4 ) + ').'  
      --   IF (RTRIM(@c_Param5 ) = '' OR CHARINDEX(' ', RTRIM(@c_Param5 )) <> 0) SET @c_ErrMsg = 'Invalid EPS PalletID (' + RTRIM(@c_Param5 ) + ').'  
      --   IF (RTRIM(@c_Param6 ) = '' OR CHARINDEX(' ', RTRIM(@c_Param6 )) <> 0) SET @c_ErrMsg = 'Invalid EPS PalletID (' + RTRIM(@c_Param6 ) + ').'  
      --   IF (RTRIM(@c_Param7 ) = '' OR CHARINDEX(' ', RTRIM(@c_Param7 )) <> 0) SET @c_ErrMsg = 'Invalid EPS PalletID (' + RTRIM(@c_Param7 ) + ').'  
      --   IF (RTRIM(@c_Param8 ) = '' OR CHARINDEX(' ', RTRIM(@c_Param8 )) <> 0) SET @c_ErrMsg = 'Invalid EPS PalletID (' + RTRIM(@c_Param8 ) + ').'  
      --   IF (RTRIM(@c_Param9 ) = '' OR CHARINDEX(' ', RTRIM(@c_Param9 )) <> 0) SET @c_ErrMsg = 'Invalid EPS PalletID (' + RTRIM(@c_Param9 ) + ').'  
      --   --IF (RTRIM(@c_Param10) = '' OR CHARINDEX(' ', RTRIM(@c_Param10)) <> 0) SET @c_ErrMsg = 'Invalid EPS PalletID (' + RTRIM(@c_Param10) + ').'  
  
      --   IF @c_ErrMsg <> ''  
      --   BEGIN  
      --    SET @c_Status = '5'  
      --      SET @c_ReasonCode = 'F05'  
      --      GOTO SEND_RESPOND  
      --   END  
  
      --END  
     
      IF RTRIM(@c_MessageName) = 'PRINTLABEL'  
      BEGIN  
         --IF RTRIM(@c_UD1) = '' OR NOT EXISTS (SELECT 1 FROM PrinterIDTable  WITH (NOLOCK) WHERE PrinterID = RTRIM(@c_UD1)  
         --BEGIN  
         --   SET @c_Status = '5'  
         --   SET @c_ReasonCode = 'F14'  
         --   SET @c_ErrMsg = 'Invalid PrinterID (' + RTRIM(@c_UD1) + ').'  
         --   GOTO SEND_RESPOND  
         --END  
  
         IF RTRIM(@c_UD2) = ''  
         BEGIN  
            SET @c_Status = '5'  
            SET @c_ReasonCode = 'F12'  
            SET @c_ErrMsg = 'Invalid Weight (' + RTRIM(@c_UD2) + ').'  
            GOTO SEND_RESPOND  
         END  
  
         IF RTRIM(@c_UD3) = ''   
         BEGIN  
            SET @c_Status = '5'  
            SET @c_ReasonCode = 'F13'  
            SET @c_ErrMsg = 'Invalid Height (' + RTRIM(@c_UD3) + ').'  
            GOTO SEND_RESPOND  
         END  
      END  
  
      IF RTRIM(@c_MessageName) = 'PHOTO'  
      BEGIN  
         IF RTRIM(@c_UD1) = ''   
         BEGIN  
            SET @c_Status = '5'  
            SET @c_ReasonCode = 'F17'  
            SET @c_ErrMsg = 'Invalid TimeStamp. Timestamp cannot be blank (' + RTRIM(@c_UD1) + ').'  
            GOTO SEND_RESPOND  
         END  
  
         IF RTRIM(@c_UD2) = '' OR ISNUMERIC(RTRIM(@c_UD2)) = 0  
         BEGIN  
            SET @c_Status = '5'  
            SET @c_ReasonCode = 'F18'  
            SET @c_ErrMsg = 'Invalid NoOfImage (' + RTRIM(@c_UD2) + ').'  
         END  
  
         IF RTRIM(@c_ImgFolderPath) = ''  
         BEGIN  
            SET @c_Status = '5'  
            SET @c_ReasonCode = 'F19'  
            SET @c_ErrMsg = 'Invalid image folder path. WCS image folder path cannot be blank.'  
            GOTO SEND_RESPOND  
         END  
  
         IF RTRIM(@c_TmpAllImg) = ''   
         BEGIN  
            SET @c_Status = '5'  
            SET @c_ReasonCode = 'F20'  
            SET @c_ErrMsg = 'Invalid image filename. Image filename cannot be blank.'  
            GOTO SEND_RESPOND  
         END  
  
         IF @n_NoOfImage >= 1 SET @c_ImgFileName1 = ISNULL(RTRIM(SUBSTRING(@c_TmpAllImg,   1, 60)),'')  
         IF @n_NoOfImage >= 2 SET @c_ImgFileName2 = ISNULL(RTRIM(SUBSTRING(@c_TmpAllImg,  61, 60)),'')  
         IF @n_NoOfImage >= 3 SET @c_ImgFileName3 = ISNULL(RTRIM(SUBSTRING(@c_TmpAllImg, 121, 60)),'')  
         IF @n_NoOfImage >= 4 SET @c_ImgFileName4 = ISNULL(RTRIM(SUBSTRING(@c_TmpAllImg, 181, 60)),'')  
         IF @n_NoOfImage >= 5 SET @c_ImgFileName5 = ISNULL(RTRIM(SUBSTRING(@c_TmpAllImg, 241, 60)),'')  
  
         IF @n_NoOfImage >= 1 AND ISNULL(RTRIM(@c_ImgFileName1),'') = ''  
         BEGIN  
            SET @c_Status = '5'  
            SET @c_ReasonCode = 'F20'  
            SET @c_ErrMsg = 'Filename1 cannot be blank. (isp_TCP_WCS_MsgPhoto)'  
            GOTO QUIT  
         END  
     
         IF @n_NoOfImage >= 2 AND ISNULL(RTRIM(@c_ImgFileName2),'') = ''  
         BEGIN  
            SET @c_Status = '5'  
            SET @c_ReasonCode = 'F20'  
            SET @c_ErrMsg = 'Filename2 cannot be blank. (isp_TCP_WCS_MsgPhoto)'  
            GOTO QUIT  
         END  
     
         IF @n_NoOfImage >= 3 AND ISNULL(RTRIM(@c_ImgFileName3),'') = ''  
         BEGIN  
            SET @c_Status = '5'  
            SET @c_ReasonCode = 'F20'  
            SET @c_ErrMsg = 'Filename3 cannot be blank. (isp_TCP_WCS_MsgPhoto)'  
          GOTO QUIT  
         END  
     
         IF @n_NoOfImage >= 4 AND ISNULL(RTRIM(@c_ImgFileName4),'') = ''  
         BEGIN  
            SET @c_Status = '5'  
            SET @c_ReasonCode = 'F20'  
            SET @c_ErrMsg = 'Filename4 cannot be blank. (isp_TCP_WCS_MsgPhoto)'  
            GOTO QUIT  
         END  
     
         IF @n_NoOfImage >= 5 AND ISNULL(RTRIM(@c_ImgFileName5),'') = ''  
         BEGIN  
            SET @c_Status = '5'  
            SET @c_ReasonCode = 'F20'  
            SET @c_ErrMsg = 'Filename5 cannot be blank. (isp_TCP_WCS_MsgPhoto)'  
            GOTO QUIT  
         END  
  
         --Commented because folder not physically located in WMS Server  
         ----Check folder exist  
         --IF OBJECT_ID('tempdb..#TmpTblDirFileExist') IS NOT NULL  
         --   DROP TABLE #TmpTblDirFileExist  
         --CREATE TABLE #TmpTblDirFileExist(FileExist INT, FolderAsFile INT, Parent INT)  
  
         --INSERT INTO #TmpTblDirFileExist  
         --EXEC master.dbo.xp_fileexist @c_ImgFolderPath  
  
         --IF NOT EXISTS (SELECT 1 FROM #TmpTblDirFileExist WITH (NOLOCK) WHERE Parent = 1)  
         --BEGIN  
         --   SET @c_Status = '5'  
         --   SET @c_ReasonCode = 'F19'  
         --   SET @c_ErrMsg = 'Invalid image folder path. WCS image folder path not exist. (' + RTRIM(@c_UD3) + ').'  
         --   GOTO SEND_RESPOND  
         --END  
  
         --SET @c_ImgFilename1 = SUBSTRING(@c_TmpAllImg,   1,  60)  
         --SET @c_ImgFilename2 = SUBSTRING(@c_TmpAllImg,  61,  60)  
         --SET @c_ImgFilename3 = SUBSTRING(@c_TmpAllImg, 121,  60)  
         --SET @c_ImgFilename4 = SUBSTRING(@c_TmpAllImg, 181,  60)  
         --SET @c_ImgFilename5 = SUBSTRING(@c_TmpAllImg, 241,  60)  
  
         ----Prepare counter to loop every image filename to check existance  
         --SET @n_Count = CONVERT(INT, RTRIM(@c_UD2) )  
         --SET @n = 1  
  
         --WHILE @n <= @n_Count   
         --BEGIN  
         --   SET @c_TmpFilename = CASE @n  
         --                           WHEN 1 THEN @c_ImgFilename1  
         --                           WHEN 2 THEN @c_ImgFilename2  
         --                           WHEN 3 THEN @c_ImgFilename3  
         --                           WHEN 4 THEN @c_ImgFilename4  
         --                           WHEN 5 THEN @c_ImgFilename5  
         --                        END  
  
         --   SET @c_TmpFilename= @c_ImgFolderPath + '\' + RTRIM(@c_TmpFilename)  
  
         --   TRUNCATE TABLE #TmpTblDirFileExist  
         --   INSERT INTO #TmpTblDirFileExist  
         --   EXEC master.dbo.xp_fileexist @c_TmpFilename  
  
         --   IF NOT EXISTS (SELECT 1 FROM #TmpTblDirFileExist WITH (NOLOCK) WHERE FileExist = 1)  
         --   BEGIN  
         --      SET @c_ErrMsg = 'Invalid image filename. Image file not exist.(' + @c_TmpFilename+ ').'  
         --      BREAK  
         --   END  
  
         --   SET @n = @n + 1  
  
         --END   --WHILE @n <= @n_Count   
  
         IF @c_ErrMsg <> ''  
         BEGIN  
            SET @c_Status = '5'  
            SET @c_ReasonCode = 'F20'  
            GOTO SEND_RESPOND  
         END  
  
      END         --IF RTRIM(@c_MessageName) = 'PHOTO'  
   END            --IF @n_continue = 1 OR @n_continue = 2  
   /*********************************************/  
   /* Message Specific Validation - END         */  
   /*********************************************/  
  
   /*********************************************/  
   /* Query SProcName to OUTPUT for caller SP   */      
   /*********************************************/  
   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN  
  
      -- If all validation success, Get SProcName based on MessageGroup and MessageName  
      SELECT @c_SProcName = ISNULL(RTRIM(SProcName),'')   
      FROM TCPSocket_Process WITH (NOLOCK)  
      WHERE StorerKey = @c_StorerKey   
      AND MessageGroup = ISNULL(RTRIM(@c_MessageGroup),'')  
      AND MessageName = ISNULL(RTRIM(@c_MessageName),'')  
  
      IF ISNULL(RTRIM(@c_SProcName),'') = ''  
      BEGIN  
         SET @n_continue = 3  
         SET @n_Err = 68006  
         SET @c_ErrMsg = 'SProcName cannot be blank. (isp_TCP_WCS_MsgValidation)'  
         GOTO QUIT  
      END  
   END  
  
   --Send respond with Error or ACK for HeartBeat Message.  
   SEND_RESPOND:  
  
   IF @b_debug = 1  
   BEGIN  
      SELECT 'SEND_RESPOND:'     [SEND_RESPOND]  
            , @c_Status          [@c_Status]  
            , @c_ReasonCode      [@c_ReasonCode]  
            , @c_ErrMsg          [@c_ErrMsg]  
  
   END  
  
   /*********************************************/  
   /* Insert Respond Message into WCSTran       */  
   /*********************************************/  
   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN  
      --Prepare temp table to store MessageID  
      IF OBJECT_ID('tempdb..#TmpTblMessageID') IS NOT NULL  
         DROP TABLE #TmpTblMessageID  
  
      CREATE TABLE #TmpTblMessageID(MessageID INT)  
  
      INSERT INTO WCSTran (MessageName, MessageType, MessageNum, WCSMessageID, OrigMessageID, PalletID, Status, ReasonCode, ErrMsg)  
      OUTPUT INSERTED.MessageID INTO #TmpTblMessageID   
      VALUES ('ACK', 'SEND', @c_MessageNum, '' , @c_WCSMessageID, @c_PalletID, @c_Status, @c_ReasonCode, @c_ErrMsg)  
  
      IF @@ERROR <> 0  
      BEGIN  
         SET @n_continue = 3  
         SET @n_err=68005     
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))   
                        + ': Insert record into WCSTran fail. (isp_TCP_WCS_MsgValidation) ( '   
                        + ' sqlsvr message=' + ISNULL(RTRIM(@c_ErrMsg), '') + ' ) '  
         GOTO QUIT  
      END  
  
      -- Get MessageID from Temp table #TmpTblMessageID  
      SELECT TOP 1 @c_AckMessageID = ISNULL(RTRIM(MessageID),'')  
      FROM #TmpTblMessageID WITH (NOLOCK)  
        
      IF @b_debug = 1  
      BEGIN  
         SELECT @c_AckMessageID [@c_AckMessageID]  
      END  
   END  
  
   /*********************************************/  
   /* Construct Respond Message                 */  
   /*********************************************/  
   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN  
     
      SET @c_AckMessageID = RIGHT(REPLICATE('0', 10) + LTRIM(RTRIM(@c_AckMessageID)),10)  
      SET @c_WCSMessageID = RIGHT(REPLICATE('0', 10) + LTRIM(RTRIM(@c_WCSMessageID)),10)  
  
      SET @c_RespondMsg = @c_AckMessageID                                              --[MessageID]  
                        + LEFT(LTRIM('ACK')              + REPLICATE(' ', 15) , 15)    --[MessageName]  
                        + @c_WCSMessageID                                              --[OrigMessageID]  
                        + LEFT(LTRIM(@c_Status)          + REPLICATE(' ', 10) , 10)    --[Status]  
                        + LEFT(LTRIM(@c_ReasonCode)      + REPLICATE(' ', 10) , 10)    --[ReasonCode]  
                        + LEFT(LTRIM(@c_ErrMsg)          + REPLICATE(' ',100) ,100)    --[ErrMsg]  
  
   END  
     
   QUIT:  
  
   IF @b_debug = 1  
   BEGIN  
      SELECT 'QUIT:'             [QUIT]  
            , @c_Status          [@c_Status]  
            , @c_ReasonCode      [@c_ReasonCode]  
            , @n_continue        [@n_continue]  
            , @n_err             [@n_err]  
            , @c_ErrMsg          [@c_ErrMsg]  
   END  
  
   UPDATE TCPSocket_INLog WITH (ROWLOCK)  
   SET    MessageNum = @c_MessageNum  
         ,STATUS = @c_Status  
         ,ErrMsg = @c_Errmsg  
   WHERE  SerialNo = @n_SerialNo  
  
   IF @@ERROR <> 0  
   BEGIN  
      SET @n_continue = 3  
      SET @n_err=68007     
      SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))   
                     + ': Update TCPSocket_INLog fail. (isp_TCP_WCS_MsgValidation) ( '   
                     + ' sqlsvr message=' + ISNULL(RTRIM(@c_ErrMsg), '') + ' ) '  
   END  
  
  
END  

GO