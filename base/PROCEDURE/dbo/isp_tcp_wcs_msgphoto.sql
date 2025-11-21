SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: isp_TCP_WCS_MsgPhoto                                */  
/* Creation Date: 25 Oct 2015                                           */  
/* Copyright: LFL                                                       */  
/* Written by: TKLIM                                                    */  
/*                                                                      */  
/* Purpose: Sub StorProc that Generate Outbound/Respond Message to WCS  */  
/*          OR Process Inbound/Respond Message from WCS                 */  
/*                                                                      */  
/* Called By: isp_TCP_WCS_MsgProcess                                    */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 1.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Date         Author    Ver.  Purposes                                */  
/* 23-Dec-2015  TKLIM     1.0   Add Multiple WCS port handling (TK09)   */  
/************************************************************************/  
  
CREATE PROCEDURE [dbo].[isp_TCP_WCS_MsgPhoto]  
     @c_MessageName     NVARCHAR(15)   = ''  --'PUTAWAY', 'MOVE', 'TSKUPD'  etc....  
   , @c_MessageType     NVARCHAR(15)   = ''  --'SEND', 'RECEIVE'  
   , @c_TaskDetailKey   NVARCHAR(10)   = ''    
   , @n_SerialNo        INT            = '0' --Serial No from TCPSocket_InLog for @c_MessageType = 'RECEIVE'  
   , @c_WCSMessageID    NVARCHAR(10)   = ''  
   , @c_OrigMessageID   NVARCHAR(10)   = ''  
   , @c_PalletID        NVARCHAR(18)   = ''  --PalletID  
   , @c_FromLoc         NVARCHAR(10)   = ''  --From Loc (Optional: Blank when calling out from ASRS)  
   , @c_ToLoc           NVARCHAR(10)   = ''  --To Loc (Blank for 'PUTAWAY')  
   , @c_Priority        NVARCHAR(1)    = ''  --for 'MOVE' and 'TSKUPD' message  
   , @c_RespStatus      NVARCHAR(10)   = ''  --for responce from WCS  
   , @c_RespReasonCode  NVARCHAR(10)   = ''  --for responce from WCS  
   , @c_RespErrMsg      NVARCHAR(100)  = ''  --for responce from WCS  
   , @c_UD1             NVARCHAR(20)   = ''  --PhotoReq / TaskUpdCode / MotherPltEmpty / PrintID / ToPallet  
   , @c_UD2             NVARCHAR(20)   = ''  --LabelReq / Weight  
   , @c_UD3             NVARCHAR(20)   = ''  --Storer / Height  
   , @c_UD4             NVARCHAR(20)   = ''  
   , @c_UD5             NVARCHAR(20)   = ''  
   , @c_Param1          NVARCHAR(20)   = ''  --PAway_SKU1  / EPS_Pallet1   
   , @c_Param2          NVARCHAR(20)   = ''  --PAway_SKU2  / EPS_Pallet2   
   , @c_Param3          NVARCHAR(20)   = ''  --PAway_SKU3  / EPS_Pallet3   
   , @c_Param4          NVARCHAR(20)   = ''  --PAway_SKU4  / EPS_Pallet4   
   , @c_Param5          NVARCHAR(20)   = ''  --PAway_SKU5  / EPS_Pallet5   
   , @c_Param6          NVARCHAR(20)   = ''  --PAway_SKU6  / EPS_Pallet6   
   , @c_Param7          NVARCHAR(20)   = ''  --PAway_SKU7  / EPS_Pallet7   
   , @c_Param8          NVARCHAR(20)   = ''  --PAway_SKU8  / EPS_Pallet8   
   , @c_Param9          NVARCHAR(20)   = ''  --PAway_SKU9  / EPS_Pallet9   
   , @c_Param10         NVARCHAR(20)   = ''  --PAway_SKU10 / EPS_Pallet10  
   , @c_CallerGroup     NVARCHAR(30)   = 'OTH'  --CallerGroup  
   , @b_debug           INT            = '0'  
   , @b_Success         INT            OUTPUT  
   , @n_Err             INT            OUTPUT  
   , @c_ErrMsg          NVARCHAR(250)  OUTPUT  
  
AS   
BEGIN   
   SET NOCOUNT ON  
   SET ANSI_DEFAULTS OFF    
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF    
  
   /*********************************************/  
   /* Variables Declaration                     */  
   /*********************************************/  
   DECLARE @n_continue           INT                  
         , @c_ExecStatements     NVARCHAR(4000)       
         , @c_ExecArguments      NVARCHAR(4000)   
      
  
   DECLARE @c_Application        NVARCHAR(50)  
         , @c_Status             NVARCHAR(1)  
         , @n_NoOfTry            INT  
  
   DECLARE @c_IniFilePath        NVARCHAR(100)  
         , @c_SendMessage        NVARCHAR(MAX)  
         , @c_LocalEndPoint      NVARCHAR(50)   
         , @c_RemoteEndPoint     NVARCHAR(50)   
         , @c_ReceiveMessage     NVARCHAR(MAX)  
         , @c_vbErrMsg           NVARCHAR(MAX)  
  
   DECLARE @c_MessageGroup       NVARCHAR(20)  
         , @c_MessageID          NVARCHAR(10)  
         , @c_TimeStamp          NVARCHAR(14)  
         , @c_NoOfImage          NVARCHAR(2)  
         , @c_Path               NVARCHAR(100)  
         , @c_ImgFileName0       NVARCHAR(300)  
         , @c_ImgFileName1       NVARCHAR(255)  
         , @c_ImgFileName2       NVARCHAR(255)  
         , @c_ImgFileName3       NVARCHAR(255)  
         , @c_ImgFileName4       NVARCHAR(255)  
         , @c_ImgFileName5       NVARCHAR(255)  
  
   DECLARE @c_ImgHyperLink       NVARCHAR(100)  
         , @n_NoOfImage          INT  
         , @c_Receiptkey         NVARCHAR(10)  
         , @c_WHRef              NVARCHAR(18)  
         , @c_Lot                NVARCHAR(10)  
         , @c_Storerkey          NVARCHAR(15)  
         , @c_SKU                NVARCHAR(40)  
         , @c_Descr              NVARCHAR(60)  
         , @c_UOM                NVARCHAR(10)  
         , @n_Qty                INT  
         , @c_DateReceived       NVARCHAR(19)  
  
   SET @n_continue               = 1   
   SET @c_ExecStatements         = ''   
   SET @c_ExecArguments          = ''  
   SET @b_Success                = '1'  
   SET @n_Err                    = 0  
   SET @c_ErrMsg                 = ''  
  
   SET @c_MessageGroup           = 'WCS'  
   SET @c_Application            = 'GenericTCPSocketClient_WCS'  
   SET @c_Status                 = '9'  
   SET @n_NoOfTry                = 0  
   SET @c_TimeStamp              = ''  
   SET @c_NoOfImage              = ''  
   SET @c_Path                   = ''  
   SET @c_ImgFileName0           = ''  
   SET @c_ImgFileName1           = ''  
   SET @c_ImgFileName2           = ''  
   SET @c_ImgFileName3           = ''  
   SET @c_ImgFileName4           = ''  
   SET @c_ImgFileName5           = ''  
  
   SET @c_ImgHyperLink           = ''  
   SET @n_NoOfImage              = 0  
   SET @c_Receiptkey             = ''  
   SET @c_WHRef                  = ''  
   SET @c_Lot                    = ''  
   SET @c_Storerkey              = ''  
   SET @c_SKU                    = ''  
   SET @c_Descr                  = ''  
   SET @c_UOM                    = ''  
   SET @n_Qty                    = 0  
   SET @c_DateReceived           = ''  
  
   /*********************************************/  
   /* Prep TCPSocketClient                      */  
   /*********************************************/     
   IF @n_Continue = 1 OR @n_Continue = 2  
   BEGIN  
  
      SELECT @c_RemoteEndPoint = Long, @c_IniFilePath = UDF01  
      FROM CODELKUP WITH (NOLOCK)  
      WHERE LISTNAME = 'TCPClient'  
        AND CODE     = 'WCS'  
        AND SHORT    = 'IN'  
        AND CODE2    = @c_CallerGroup      --TK09  
  
      IF ISNULL(@c_RemoteEndPoint,'') = ''  
      BEGIN  
         SET @b_Success = 0  
         SET @n_Err = 68002    
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))   
                       + ': Remote End Point cannot be empty. (isp_TCP_WCS_MsgPhoto)'    
         GOTO QUIT   
      END  
  
      IF ISNULL(@c_IniFilePath,'') = ''  
      BEGIN  
         SET @b_Success = 0  
         SET @n_Err = 68003    
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))   
                       + ': TCPClient Ini File Path cannot be empty. (isp_TCP_WCS_MsgPhoto)'    
         GOTO QUIT   
  END  
   END  
  
   IF @b_debug = 1  
   BEGIN  
      SELECT 'INIT DATA'  
            ,@c_IniFilePath      [@c_IniFilePath]  
            ,@c_RemoteEndPoint   [@c_RemoteEndPoint]   
            ,@c_MessageName      [@c_MessageName]  
            ,@c_MessageType      [@c_MessageType]  
            ,@c_TaskDetailKey    [@c_TaskDetailKey]  
            ,@c_WCSMessageID     [@c_WCSMessageID]  
            ,@c_OrigMessageID    [@c_OrigMessageID]  
            ,@c_PalletID         [@c_PalletID]  
            ,@c_FromLoc          [@c_FromLoc]  
            ,@c_ToLoc            [@c_ToLoc]  
            ,@c_Priority         [@c_Priority]  
            ,@c_RespStatus       [@c_RespStatus]  
            ,@c_RespReasonCode   [@c_RespReasonCode]  
            ,@c_RespErrMsg       [@c_RespErrMsg]  
            ,@c_UD1              [@c_UD1]  
            ,@c_UD2              [@c_UD2]  
            ,@c_UD3              [@c_UD3]  
            ,@c_UD4              [@c_UD4]  
            ,@c_UD5              [@c_UD5]  
            ,@c_Param1           [@c_Param1]  
            ,@c_Param2           [@c_Param2]  
            ,@c_Param3           [@c_Param3]  
            ,@c_Param4           [@c_Param4]  
            ,@c_Param5           [@c_Param5]  
            ,@c_Param6           [@c_Param6]  
            ,@c_Param7           [@c_Param7]  
            ,@c_Param8           [@c_Param8]  
            ,@c_Param9           [@c_Param9]  
            ,@c_Param10          [@c_Param10]  
   END  
  
   /*********************************************/  
   /* Validation                                */  
   /*********************************************/  
   IF @n_Continue = 1 OR @n_Continue = 2  
   BEGIN  
  
      IF @n_SerialNo = '0'  
      BEGIN  
         SET @b_Success = 0  
         SET @n_Err = 68011  
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))   
                       + 'SerialNo cannot be blank. (isp_TCP_WCS_MsgPhoto)'  
         GOTO QUIT  
      END  
  
      SELECT @c_MessageID     = SUBSTRING(Data,   1,  10)  
           , @c_MessageName   = SUBSTRING(Data,  11,  15)  
           , @c_PalletID      = SUBSTRING(Data,  26,  18)  
           , @c_TimeStamp     = SUBSTRING(Data,  44,  14)  
           , @c_NoOfImage     = SUBSTRING(Data,  58,   2)  
           , @c_Path          = SUBSTRING(Data,  60, 100)  
           , @c_ImgFileName0  = SUBSTRING(Data, 160, 300)  
      FROM TCPSOCKET_INLOG WITH (NOLOCK)  
      WHERE SerialNo = @n_SerialNo  
  
  
      IF @b_Debug = 1  
      BEGIN  
         SELECT @c_MessageID     [@c_MessageID  ]  
              , @c_MessageName   [@c_MessageName]  
              , @c_PalletID      [@c_PalletID   ]  
              , @c_TimeStamp     [@c_TimeStamp  ]  
              , @c_NoOfImage     [@c_NoOfImage  ]  
              , @c_Path          [@c_Path       ]  
              , @c_ImgFileName0  [@c_ImgFileName0  ]  
      END  
  
  
      IF ISNULL(RTRIM(@c_MessageName),'') = ''  
      BEGIN  
         SET @c_RespReasonCode = ''  
         SET @b_Success = 0  
         SET @n_Err = 68012  
         SET @c_ErrMsg = 'MessageName cannot be blank. (isp_TCP_WCS_MsgPhoto)'  
         GOTO QUIT  
      END  
  
      IF ISNULL(RTRIM(@c_PalletID),'') = ''  
      BEGIN  
         SET @c_RespReasonCode = ''  
         SET @b_Success = 0  
         SET @n_Err = 68013  
         SET @c_ErrMsg = 'PalletID cannot be blank. (isp_TCP_WCS_MsgPhoto)'  
         GOTO QUIT  
      END  
   
      IF ISNULL(RTRIM(@c_Path),'') = ''  
      BEGIN  
         SET @c_RespReasonCode = ''  
         SET @b_Success = 0  
         SET @n_Err = 68013  
         SET @c_ErrMsg = 'Image Path cannot be blank. (isp_TCP_WCS_MsgPhoto)'  
         GOTO QUIT  
      END  
  
      IF ISNULL(RTRIM(@c_ImgFileName0),'') = ''  
      BEGIN  
         SET @c_RespReasonCode = ''  
         SET @b_Success = 0  
         SET @n_Err = 68013  
         SET @c_ErrMsg = 'Image Filenames cannot be blank. (isp_TCP_WCS_MsgPhoto)'  
         GOTO QUIT  
      END  
    
      IF ISNULL(RTRIM(@c_NoOfImage),'') = '' OR ISNUMERIC(ISNULL(RTRIM(@c_NoOfImage),'')) <> 1  
      BEGIN  
         SET @c_RespReasonCode = ''  
         SET @b_Success = 0  
         SET @n_Err = 68014  
         SET @c_ErrMsg = 'NoOfImage must be Numeric and cannot be blank. (isp_TCP_WCS_MsgPhoto)'  
         GOTO QUIT  
      END  
        
      SET @n_NoOfImage = CONVERT(INT,ISNULL(RTRIM(@c_NoOfImage),0))  
  
      IF @n_NoOfImage = 0  
      BEGIN  
         SET @c_RespReasonCode = ''  
         SET @b_Success = 0  
         SET @n_Err = 68015  
         SET @c_ErrMsg = 'NoOfImage must be > 0. (isp_TCP_WCS_MsgPhoto)'  
         GOTO QUIT  
      END  
  
      IF @n_NoOfImage >= 1 SET @c_ImgFileName1 = ISNULL(RTRIM(SUBSTRING(@c_ImgFileName0,   1, 60)),'')  
      IF @n_NoOfImage >= 2 SET @c_ImgFileName2 = ISNULL(RTRIM(SUBSTRING(@c_ImgFileName0,  61, 60)),'')  
      IF @n_NoOfImage >= 3 SET @c_ImgFileName3 = ISNULL(RTRIM(SUBSTRING(@c_ImgFileName0, 121, 60)),'')  
      IF @n_NoOfImage >= 4 SET @c_ImgFileName4 = ISNULL(RTRIM(SUBSTRING(@c_ImgFileName0, 181, 60)),'')  
      IF @n_NoOfImage >= 5 SET @c_ImgFileName5 = ISNULL(RTRIM(SUBSTRING(@c_ImgFileName0, 241, 60)),'')  
  
      IF @n_NoOfImage >= 1 AND ISNULL(RTRIM(@c_ImgFileName1),'') = ''  
      BEGIN  
         SET @c_RespReasonCode = ''  
         SET @b_Success = 0  
         SET @n_Err = 68014  
         SET @c_ErrMsg = 'Filename1 cannot be blank. (isp_TCP_WCS_MsgPhoto)'  
         GOTO QUIT  
      END  
     
      IF @n_NoOfImage >= 2 AND ISNULL(RTRIM(@c_ImgFileName2),'') = ''  
      BEGIN  
         SET @c_RespReasonCode = ''  
         SET @b_Success = 0  
         SET @n_Err = 68014  
         SET @c_ErrMsg = 'Filename2 cannot be blank. (isp_TCP_WCS_MsgPhoto)'  
         GOTO QUIT  
      END  
     
      IF @n_NoOfImage >= 3 AND ISNULL(RTRIM(@c_ImgFileName3),'') = ''  
      BEGIN  
         SET @c_RespReasonCode = ''  
         SET @b_Success = 0  
         SET @n_Err = 68014  
         SET @c_ErrMsg = 'Filename3 cannot be blank. (isp_TCP_WCS_MsgPhoto)'  
         GOTO QUIT  
      END  
     
      IF @n_NoOfImage >= 4 AND ISNULL(RTRIM(@c_ImgFileName4),'') = ''  
      BEGIN  
         SET @c_RespReasonCode = ''  
         SET @b_Success = 0  
         SET @n_Err = 68014  
         SET @c_ErrMsg = 'Filename4 cannot be blank. (isp_TCP_WCS_MsgPhoto)'  
         GOTO QUIT  
      END  
     
      IF @n_NoOfImage >= 5 AND ISNULL(RTRIM(@c_ImgFileName5),'') = ''  
      BEGIN  
         SET @c_RespReasonCode = ''  
         SET @b_Success = 0  
         SET @n_Err = 68014  
         SET @c_ErrMsg = 'Filename5 cannot be blank. (isp_TCP_WCS_MsgPhoto)'  
         GOTO QUIT  
      END  
  
   END  
  
   IF @n_Continue = 1 OR @n_Continue = 2  
   BEGIN  
  
      SELECT @c_ImgHyperLink = ISNULL(LTRIM(RTRIM(Notes)),'') FROM CODELKUP WITH (NOLOCK) WHERE ListName = 'PLTIMAGE'  
  
      IF @c_ImgHyperLink = ''  
      BEGIN  
         SET @c_RespReasonCode = ''  
         SET @b_Success = 0  
         SET @n_Err = 68015  
         SET @c_ErrMsg = 'PLTIMAGE not setup in Codelkup. (isp_TCP_WCS_MsgPhoto)'  
         GOTO QUIT  
      END  
        
      IF @c_ImgFileName1 <> '' SET @c_ImgFileName1 = @c_ImgHyperLink + @c_ImgFileName1  
      IF @c_ImgFileName2 <> '' SET @c_ImgFileName2 = @c_ImgHyperLink + @c_ImgFileName2  
      IF @c_ImgFileName3 <> '' SET @c_ImgFileName3 = @c_ImgHyperLink + @c_ImgFileName3  
      IF @c_ImgFileName4 <> '' SET @c_ImgFileName4 = @c_ImgHyperLink + @c_ImgFileName4  
      IF @c_ImgFileName5 <> '' SET @c_ImgFileName5 = @c_ImgHyperLink + @c_ImgFileName5  
  
      IF @c_MessageType = 'RECEIVE'  
      BEGIN  
  
         ---- INSERT INTO WCSTran  
         --INSERT INTO WCSTran (MessageName, MessageType, WCSMessageID, PalletID, UD1, UD2, ImgFolderPath, ImgFileName1, ImgFileName2, ImgFileName3, ImgFileName4, ImgFileName5)  
         --VALUES (@c_MessageName, @c_MessageType, @c_MessageID, @c_PalletID, @c_TimeStamp, @c_NoOfImage, @c_Path, @c_ImgFileName1, @c_ImgFileName2, @c_ImgFileName3, @c_ImgFileName4, @c_ImgFileName5)  
  
         --IF @@ERROR <> 0  
         --BEGIN  
         --   SET @b_Success = 0  
         --   SET @n_err=68031     
         --   SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))   
         --                 + ': Insert record into WCSTran fail. (isp_TCP_WCS_MsgPhoto)'  
         --                 + ' sqlsvr message=' + ISNULL(RTRIM(@c_ErrMsg), '')  
         --   GOTO QUIT  
         --END  
  
         --Validate and only capture photo when pallet contain only 1 lot.  
         DECLARE C_QRYLLI CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
         SELECT LLI.Lot  
              , LLI.SKU  
              , LLI.Storerkey  
         FROM LOTxLOCxID LLI WITH (NOLOCK)  
         WHERE LLI.ID = @c_PalletID AND LLI.QTY > 0  
  
         OPEN C_QRYLLI  
         FETCH NEXT FROM C_QRYLLI INTO @c_Lot, @c_SKU, @c_Storerkey  
  
         WHILE @@FETCH_STATUS <> -1   
         BEGIN  
  
            SELECT TOP 1 @c_Receiptkey    = RH.Receiptkey  
                       , @c_WHRef         = RH.Warehousereference  
                       , @c_Descr         = SKU.DESCR  
                       , @c_UOM           = RD.UOM  
                       , @n_Qty           = RD.QtyReceived  
                       , @c_DateReceived  = CONVERT(VARCHAR(19), RD.DateReceived, 120)  
            FROM ITRN ITRN WITH (NOLOCK)  
            JOIN ReceiptDetail RD WITH (NOLOCK)  
            ON  RD.ReceiptKey = LEFT(ITRN.Sourcekey,10)   
            AND RD.ReceiptLineNumber = SUBSTRING(ISNULL(RTRIM(ITRN.Sourcekey),''),11,5)  
            AND RD.SKU = ITRN.SKU  
            AND RD.Storerkey = ITRN.Storerkey  
            AND RD.ToID = ITRN.ToID  
            JOIN Receipt RH WITH (NOLOCK)  
            ON RH.ReceiptKey = RD.ReceiptKey  
            LEFT OUTER JOIN SKU SKU WITH (NOLOCK)  
            ON SKU.SKU = RD.SKU  
            WHERE ITRN.TranType     = 'DP'  
              AND ITRN.SourceType   = 'ntrReceiptDetailUpdate'  
              AND ITRN.Lot          = @c_Lot  
              AND ITRN.ToID         = @c_PalletID  
              AND ITRN.SKU          = @c_SKU  
              AND ITRN.Storerkey    = @c_Storerkey  
            ORDER BY ItrnKey DESC  
  
            INSERT INTO PALLETIMAGE (Receiptkey, PermitNo, LotNo, ID, Storerkey, Sku, Descr, UOM, QtyReceived, ReceiptDate, ImageUrl01, ImageUrl02, ImageUrl03, ImageUrl04, ImageUrl05)  
            VALUES (@c_ReceiptKey, @c_WHRef, @c_Lot, @c_PalletID, @c_Storerkey, @c_SKU, @c_Descr, @c_UOM, @n_Qty, @c_DateReceived, @c_ImgFileName1, @c_ImgFileName2, @c_ImgFileName3, @c_ImgFileName4, @c_ImgFileName5)  
   
            IF @@ERROR <> 0  
            BEGIN  
               SET @b_Success = 0  
               SET @n_err=68020     
               SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))   
                             + ': Insert record into PALLETIMAGE fail. (isp_TCP_WCS_MsgPhoto)'  
                             + ' sqlsvr message=' + ISNULL(RTRIM(@c_ErrMsg), '')  
               GOTO QUIT  
            END  
  
            FETCH NEXT FROM C_QRYLLI INTO @c_Lot, @c_SKU, @c_Storerkey  
  
         END--WHILE @@FETCH_STATUS <> -1   
         CLOSE C_QRYLLI  
         DEALLOCATE C_QRYLLI  
    
      END   --IF @c_MessageType = 'RECEIVE'  
   END      --IF @n_Continue = 1 OR @n_Continue = 2  
  
   QUIT:  
  
END  
  
  

GO