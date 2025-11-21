SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: ispCTNLBLITF06                                     */
/* Creation Date: 07-Jul-2023                                           */
/* Copyright: MAERSK                                                    */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-22643 - SG - LEGOEC - ECOM Exceed Packing Module        */
/*                                                                      */
/* Called By: isp_PrintCartonLabel_Interface                            */
/*                                                                      */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 07-Jul-2023 WLChooi  1.0   DevOps Combine Script                     */
/************************************************************************/
CREATE   PROCEDURE [dbo].[ispCTNLBLITF06]
   @c_Pickslipno   NVARCHAR(10)
 , @n_CartonNo_Min INT
 , @n_CartonNo_Max INT
 , @b_Success      INT           OUTPUT
 , @n_Err          INT           OUTPUT
 , @c_ErrMsg       NVARCHAR(255) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue     INT
         , @n_starttcnt    INT
         , @n_SUMPackQty   INT         = 0
         , @n_SUMPickQty   INT         = 0
         , @c_Orderkey     NVARCHAR(10)
         , @c_ECOM_S_Flag  NVARCHAR(1)
         , @c_Storerkey    NVARCHAR(15)
         , @c_Shipperkey   NVARCHAR(45)
         , @c_TrackingNo   NVARCHAR(20)
         , @n_Cartonno     INT
         , @c_UserID       NVARCHAR(30)
         , @c_PrinterID    NVARCHAR(20)
         , @c_LabelType    NVARCHAR(30)
         , @c_Facility     NVARCHAR(10)
         , @c_Parm01       NVARCHAR(80)
         , @c_Parm02       NVARCHAR(80)
         , @c_Parm03       NVARCHAR(80)
         , @c_Parm04       NVARCHAR(80)
         , @c_Parm05       NVARCHAR(80)
         , @c_Parm06       NVARCHAR(80)
         , @c_Parm07       NVARCHAR(80)
         , @c_Parm08       NVARCHAR(80)
         , @c_Parm09       NVARCHAR(80)
         , @c_Parm10       NVARCHAR(80)
         , @c_Returnresult NVARCHAR(20)
         , @c_key2         NVARCHAR(30)
         , @c_Trmlogkey    NVARCHAR(10)

   DECLARE @c_Command         NVARCHAR(1000) = ''
         , @c_IP              VARCHAR(20)    = ''
         , @c_Port            VARCHAR(10)    = ''
         , @n_ThreadPerAcct   INT            = 0
         , @n_MilisecondDelay INT            = 0
         , @c_APP_DB_Name     VARCHAR(30)    = ''
         , @n_ThreadPerStream INT            = 0
         , @c_IniFilePath     NVARCHAR(200)  = ''
         , @c_DataStream      VARCHAR(10)    = '7371'

   DECLARE @c_PrintCartonLabelByITF NVARCHAR(100)
         , @c_Option1               NVARCHAR(255)
         , @c_Option2               NVARCHAR(255)
         , @c_Option3               NVARCHAR(255)
         , @c_Tablename             NVARCHAR(50) = ''

   SET @n_Err = 0
   SET @b_Success = 1
   SET @c_ErrMsg = ''
   SET @n_continue = 1
   SET @n_starttcnt = @@TRANCOUNT

   SET @c_TrackingNo = N''
   SET @n_Cartonno = 1

   SET @c_UserID = SUSER_SNAME()
   SET @c_LabelType = N'UCCLBLSG04'

   SET @c_Parm01 = N''
   SET @c_Parm02 = N''
   SET @c_Parm03 = N''
   SET @c_Parm04 = N''
   SET @c_Parm05 = N''
   SET @c_Parm06 = N''
   SET @c_Parm07 = N''
   SET @c_Parm08 = N''
   SET @c_Parm09 = N''
   SET @c_Parm10 = N''

   SELECT TOP 1 @c_Facility = DefaultFacility
              , @c_PrinterID = DefaultPrinter
   FROM RDT.RDTUser (NOLOCK)
   WHERE UserName = @c_UserID

   SELECT @c_Storerkey = ORDERS.StorerKey
        , @c_Orderkey = ORDERS.OrderKey
        , @c_Shipperkey = ORDERS.ShipperKey
        , @c_ECOM_S_Flag = ORDERS.ECOM_SINGLE_Flag
   FROM PackHeader (NOLOCK)
   JOIN ORDERS (NOLOCK) ON PackHeader.OrderKey = ORDERS.OrderKey
   WHERE PackHeader.PickSlipNo = @c_Pickslipno

   IF @n_CartonNo_Min = @n_CartonNo_Max
   BEGIN
      SET @n_Cartonno = @n_CartonNo_Min
   END
   ELSE
   BEGIN
      SELECT @n_Cartonno = MAX(PD.CartonNo)
      FROM dbo.PackDetail PD WITH (NOLOCK)
      WHERE PD.PickSlipNo = @c_Pickslipno
   END

   SELECT TOP 1 @c_TrackingNo = PIF.TrackingNo
   FROM PackInfo PIF WITH (NOLOCK)
   WHERE PIF.PickSlipNo = @c_Pickslipno AND PIF.CartonNo = @n_Cartonno

   EXEC nspGetRight ''
                  , @c_Storerkey
                  , ''
                  , 'PrintCartonLabelByITF'
                  , @b_Success OUTPUT
                  , @c_PrintCartonLabelByITF OUTPUT
                  , @n_Err OUTPUT
                  , @c_ErrMsg OUTPUT
                  , @c_Option1 OUTPUT
                  , @c_Option2 OUTPUT
                  , @c_Option3 OUTPUT

   IF @c_PrintCartonLabelByITF = '1'
   BEGIN
      --For shipperkey='ninjavan' check if packinfo.trackingno . if packinfo.trackingno is null or blank trigger insert transmitlog2 else print bartender label  
      --For shipperkey <> 'ninjavan' and tracking no is blank or null update packinfo and packdetail before print bartender label else direct print bartender label
      --Skip insert Transmitlog2 in isp_PrintCartonLabel_Interface  
      IF @c_Shipperkey = 'NinjaVan' AND ISNULL(@c_TrackingNo, '') = ''
      BEGIN
         DECLARE CUR_TL2 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT @c_Option1 UNION ALL SELECT 'WSCRINTPACKNJV'

         OPEN CUR_TL2

         FETCH NEXT FROM CUR_TL2 INTO @c_Tablename

         WHILE @@FETCH_STATUS <> -1
         BEGIN
            SELECT @b_Success = 1
            EXECUTE nspg_GetKey 'TransmitlogKey2'
                              , 10
                              , @c_Trmlogkey OUTPUT
                              , @b_Success OUTPUT
                              , @n_Err OUTPUT
                              , @c_ErrMsg OUTPUT
            
            IF @b_Success <> 1
            BEGIN
               SELECT @n_continue = 3
            END
            ELSE
            BEGIN
               INSERT INTO TRANSMITLOG2 (transmitlogkey, tablename, key1, key2, key3, transmitflag, transmitbatch)
               VALUES (@c_Trmlogkey, @c_Tablename, SUBSTRING(@c_Pickslipno, 2, 9) + CONVERT(NVARCHAR(5), @n_Cartonno)
                     , @c_UserID, @c_Storerkey, '0', '')
            
               IF @@ERROR <> 0          
               BEGIN          
                  SET @n_continue = 3  
                  SET @c_errmsg = ERROR_MESSAGE()        
                  SET @n_err = 64305          
                  SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0)) +           
                                + ': Insert into TRANSMITLOG2 Failed. (ispCTNLBLITF06) '
                                + '( SQLSvr MESSAGE = ' + @c_errmsg + ' ) '          
                  GOTO QUIT_SP          
               END 
            
               SELECT @c_Command = StoredProcName + ',@c_TransmitlogKey=''' + @c_Trmlogkey + ''' ' 
                    , @c_IP = [IP]
                    , @c_Port = [Port]
                    , @n_ThreadPerAcct = ThreadPerAcct
                    , @n_MilisecondDelay = MilisecondDelay 
                    , @c_APP_DB_Name = App_DB_Name    --TargetDB      
                    , @c_IniFilePath = IniFilePath                
                    , @n_ThreadPerStream = ThreadPerStream        
               FROM QCmd_TransmitlogConfig WITH (NOLOCK)  
               WHERE DataStream = @c_DataStream 
                  AND TableName = @c_Tablename  
                  AND StorerKey = @c_StorerKey
               
               SET @c_Command = REPLACE(@c_Command, 'EXEC ', '')
               SET @c_Command = 'EXEC ' + TRIM(@c_APP_DB_Name) + '.dbo.' + @c_Command
               
               BEGIN TRY    
                  EXEC isp_QCmd_SubmitTaskToQCommander     
                        @cTaskType        = 'T'-- D=By Datastream, T=Transmitlog, O=Others           
                     ,  @cStorerKey       = @c_StorerKey                                                
                     ,  @cDataStream      = @c_DataStream                                                         
                     ,  @cCmdType         = 'SQL'                                                      
                     ,  @cCommand         = @c_Command                                                  
                     ,  @cTransmitlogKey  = @c_Trmlogkey                                             
                     ,  @nThreadPerAcct   = @n_ThreadPerAcct                                                    
                     ,  @nThreadPerStream = @n_ThreadPerStream                                                          
                     ,  @nMilisecondDelay = @n_MilisecondDelay                                                          
                     ,  @nSeq             = 1                           
                     ,  @cIP              = @c_IP                                             
                     ,  @cPORT            = @c_PORT                                                    
                     ,  @cIniFilePath     = @c_IniFilePath           
                     ,  @cAPPDBName       = @c_APP_DB_Name                                                   
                     ,  @bSuccess         = @b_Success      OUTPUT                                     
                     ,  @nErr             = @n_Err          OUTPUT      
                     ,  @cErrMsg          = @c_ErrMsg       OUTPUT 
                     ,  @nPriority        = 2                                                    
               END TRY    
               BEGIN CATCH  
                  SET @n_Continue = 3 
                  SET @n_err = 64310   
                  SET @c_ErrMsg = ERROR_MESSAGE()
                  SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0)) +           
                             + ': Error Executing isp_QCmd_SubmitTaskToQCommander. (ispCTNLBLITF06) '
                             + '( SQLSvr MESSAGE = ' + @c_errmsg + ' ) '    
                  GOTO QUIT_SP 
               END CATCH 
            END

            FETCH NEXT FROM CUR_TL2 INTO @c_Tablename
         END
         CLOSE CUR_TL2
         DEALLOCATE CUR_TL2
      END
      ELSE --shipperkey <> 'ninjavan'
      BEGIN
         EXEC isp_BT_GenBartenderCommand @cPrinterID = @c_PrinterID
                                       , @c_LabelType = @c_LabelType
                                       , @c_userid = @c_UserID
                                       , @c_Parm01 = @c_Pickslipno
                                       , @c_Parm02 = @n_Cartonno
                                       , @c_Parm03 = @n_Cartonno
                                       , @c_Parm04 = @c_Parm04
                                       , @c_Parm05 = @c_Parm05
                                       , @c_Parm06 = @c_Parm06
                                       , @c_Parm07 = @c_Parm07
                                       , @c_Parm08 = @c_Parm08
                                       , @c_Parm09 = @c_Parm09
                                       , @c_Parm10 = @c_Parm10
                                       , @c_StorerKey = @c_Storerkey
                                       , @c_NoCopy = '1'
                                       , @c_Returnresult = 'N'
                                       , @n_err = @n_Err OUTPUT
                                       , @c_errmsg = @c_ErrMsg OUTPUT

         IF @n_Err <> 0
         BEGIN
            SELECT @n_continue = 3
            GOTO QUIT_SP
         END
         ELSE
         BEGIN
            SET @n_continue = 1
            SET @c_ErrMsg = ''
         END
      END

      SET @b_Success = 2
   END
   QUIT_SP:

   IF CURSOR_STATUS('LOCAL', 'CUR_TL2') IN (0 , 1)
   BEGIN
      CLOSE CUR_TL2
      DEALLOCATE CUR_TL2   
   END

   IF @n_continue = 3 -- Error Occured - Process And Return  
   BEGIN
      SELECT @b_Success = 0
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_starttcnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_starttcnt
         BEGIN
            COMMIT TRAN
         END
      END
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispCTNLBLITF06'
      RAISERROR(@c_ErrMsg, 16, 1) WITH SETERROR -- SQL2012  
      RETURN
   END
   ELSE
   BEGIN
      SELECT @b_Success = 1
      WHILE @@TRANCOUNT > @n_starttcnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END

GO