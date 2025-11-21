SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
    
/************************************************************************/        
/* Trigger: isp_EPackCtnTrack09                                         */        
/* Creation Date: 06-APR-2022                                           */        
/* Copyright: LF Logistics                                              */        
/* Written by: Mingle                                                   */        
/*                                                                      */        
/* Purpose: WMS-19152 - CN BELIV ECOM PACKING trigger point             */        
/*        :                                                             */        
/* Called By: n_cst_packcarton_ecom                                     */        
/*          : ue_getcartontrackno                                       */        
/*        :                                                             */        
/* PVCS Version: 1.4                                                    */        
/*                                                                      */        
/* Version: 7.0                                                         */        
/*                                                                      */        
/* Data Modifications:                                                  */        
/*                                                                      */        
/* Updates:                                                             */        
/* Date        Author   Ver   Purposes                                  */        
/* 06-APR-2022 Mingle   1.0   Created(WMS-19152)                        */  
/* 06-APR-2022 Mingle   1.0   DevOps Combine Script                     */    
/* 04-Aug-2022 WLChooi  1.1   WMS-20403 Get Info from Option5 (WL01)    */
/* 30-Sep-2022 WLChooi  1.2   WMS-20913 Get Info from Option5 filter    */
/*                            by ECOM Platform (WL02)                   */
/* 08-Feb-2023 WLChooi  1.3   WMS-21728 - Add prefix to TL2.KeyXX (WL03)*/
/* 24-Feb-2023 WLChooi  1.4   WMS-21728 - Bug Fix (WL04)                */
/************************************************************************/        
CREATE   PROC [dbo].[isp_EPackCtnTrack09]        
         @c_PickSlipNo  NVARCHAR(10)         
      ,  @n_CartonNo    INT        
      ,  @c_CTNTrackNo  NVARCHAR(40)         OUTPUT        
      ,  @b_Success     INT = 0              OUTPUT   -- 0:Fail, 1:Success 2:Success with Track # is lock        
      ,  @n_err         INT = 0              OUTPUT         
      ,  @c_errmsg      NVARCHAR(255) = ''   OUTPUT         
AS        
BEGIN        
   SET NOCOUNT ON        
   SET ANSI_NULLS OFF        
   SET QUOTED_IDENTIFIER OFF        
   SET CONCAT_NULL_YIELDS_NULL OFF        
        
   DECLARE @n_StartTCnt       INT         = @@TRANCOUNT         
         , @n_Continue        INT         = 1  
     
         , @c_TableName       NVARCHAR(15)= ''
         , @c_CartonNo        NVARCHAR(10)= ''
         , @c_Orderkey        NVARCHAR(10)= ''      
         , @c_Storerkey       NVARCHAR(15)= '' 
         , @c_TaskBatchNo     NVARCHAR(10)= '' 
         
         , @c_Command         NVARCHAR(1000)=''
         , @c_TransmitlogKey  NVARCHAR(10)  =''
         , @c_IP              VARCHAR(20)   =''
         , @c_Port            VARCHAR(10)   =''
         , @n_ThreadPerAcct   INT           =0
         , @n_MilisecondDelay INT           =0
         , @c_APP_DB_Name     VARCHAR(30)   =''    
         , @n_ThreadPerStream INT           =0
         , @c_IniFilePath     NVARCHAR(200) =''
         , @c_DataStream      VARCHAR(10)   ='6157'
         , @b_SuccessOld      INT   
         , @c_UpdateCT        NVARCHAR(1) = 'N'  
         , @n_RowRef          BIGINT   
         , @c_Facility        NVARCHAR(5)    --WL01
         , @c_SValue          NVARCHAR(50)   --WL01
         , @c_Option1         NVARCHAR(50) = ''   --WL01
         , @c_Option2         NVARCHAR(50) = ''   --WL01
         , @c_Option3         NVARCHAR(50) = ''   --WL01
         , @c_Option4         NVARCHAR(50) = ''   --WL01
         , @c_Option5         NVARCHAR(4000) = '' --WL01
         , @c_ECOMPlatform    NVARCHAR(20) = ''   --WL02
         , @c_ECPlatform_JSON NVARCHAR(MAX) = ''   --WL02
         , @c_TL2KeyPrefix    NVARCHAR(MAX) = ''   --WL03
         , @c_Key1Prefix      NVARCHAR(20) = ''   --WL03
         , @c_Key2Prefix      NVARCHAR(20) = ''   --WL03
         , @c_Key3Prefix      NVARCHAR(20) = ''   --WL03

   SET @b_Success  = 1        
   SET @n_err      = 0        
   SET @c_errmsg   = ''        
        
   WHILE @@TRANCOUNT > 0         
   BEGIN        
      COMMIT TRAN        
   END        
        
   SET @c_Orderkey = ''    
   SET @c_CTNTrackNo = ''   --WL04
   
   --WL01 S
   SELECT @c_Orderkey      = PACKHEADER.Orderkey         
         ,@c_Storerkey     = PACKHEADER.Storerkey
         ,@c_TaskBatchNo   = PACKHEADER.TaskBatchNo 
         ,@c_Facility      = ORDERS.Facility
         ,@c_ECOMPlatform  = ORDERS.ECOM_Platform   --WL02
   FROM PACKHEADER WITH (NOLOCK)    
   JOIN ORDERS WITH (NOLOCK) ON ORDERS.OrderKey = PACKHEADER.OrderKey
   WHERE PickSlipNo = @c_PickSlipNo  
   --WL01 E
        
   IF @c_Orderkey = ''        
   BEGIN 
      SET @n_continue = 3        
      SET @n_err = 60010          
      SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Orderkey is required to get Tracking #. (isp_EPackCtnTrack09)'         
      GOTO QUIT_SP                      
   END   
   
   --WL01 S
   EXEC nspGetRight  
      @c_Facility          -- facility  
   ,  @c_Storerkey         -- Storerkey  
   ,  NULL                 -- Sku  
   ,  'EPackCtnTrackNo_SP' -- Configkey  
   ,  @b_Success                 OUTPUT   
   ,  @c_SValue                  OUTPUT   
   ,  @n_Err                     OUTPUT   
   ,  @c_ErrMsg                  OUTPUT 
   ,  @c_Option1                 OUTPUT
   ,  @c_Option2                 OUTPUT
   ,  @c_Option3                 OUTPUT
   ,  @c_Option4                 OUTPUT
   ,  @c_Option5                 OUTPUT

   IF @b_success <> 1  
   BEGIN  
      SET @n_continue = 3  
      SET @n_err = 60014   
      SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Executing nspGetRight. (isp_EPackCtnTrack09)'   
                  + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '   
      GOTO QUIT_SP  
   END 
   --WL01 E
   
   --Get TrackingNo from Orders Header since Storerconfig ValidateTrackNo = '1' if CartonNo = 1 AND PackInfo is not exists
   IF NOT EXISTS (SELECT 1
                  FROM PACKINFO PIF (NOLOCK)
                  WHERE PIF.PickSlipNo = @c_PickSlipNo
                  AND PIF.CartonNo = @n_CartonNo) AND @n_CartonNo = 1
   BEGIN
      SELECT @c_CTNTrackNo = OH.TrackingNo
      FROM ORDERS OH (NOLOCK)
      WHERE OH.OrderKey = @c_Orderkey
   END

   IF NOT EXISTS (SELECT 1
                  FROM PACKINFO PIF (NOLOCK)
                  WHERE PIF.PickSlipNo = @c_PickSlipNo
                  AND PIF.CartonNo = @n_CartonNo) AND @n_CartonNo > 1
   BEGIN
      SELECT TOP 1 @n_RowRef = CT.RowRef
                 , @c_CTNTrackNo = CT.TrackingNo
      FROM CARTONTRACK CT (NOLOCK)
      WHERE CT.LabelNo = @c_Orderkey
      AND CT.CarrierRef2 <> 'GET'
      AND CT.CarrierRef1 = @c_Orderkey + CAST(@n_CartonNo AS NVARCHAR)
      ORDER BY CT.AddDate

      IF ISNULL(@n_RowRef,0) > 0
      BEGIN
         SET @c_UpdateCT = 'Y'
      END
   END

   IF ISNULL(@c_CTNTrackNo,'') <> ''
   BEGIN
      INSERT INTO PACKINFO 
               (  PickSlipNo
               ,  CartonNo
               ,  [Weight]
               ,  [Cube]
               ,  Height
               ,  [Length]
               ,  Width 
               ,  TrackingNo
               )
      VALUES(  @c_PickSlipNo
            ,  @n_CartonNo
            ,  0.00
            ,  0.00
            ,  0.00
            ,  0.00
            ,  0.00  
            ,  @c_CTNTrackNo
            )	
	   
      SET @n_err = @@ERROR

      IF @n_err <> 0
      BEGIN
         SET @n_continue = 3
         SET @n_err = 60015  
         SET @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': Error Insert PACKINFO Table. (isp_EPackCtnTrack09)' 
                           + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
         GOTO QUIT_SP
      END

      SET @b_Success = 2   --Tell ECOM Packing to refresh Packinfo, do not insert PackInfo again
      SET @b_SuccessOld = @b_Success

      IF @c_UpdateCT = 'Y' AND ISNULL(@c_CTNTrackNo,'') <> ''
      BEGIN
         UPDATE dbo.CartonTrack
         SET CarrierRef2 = 'GET'
         WHERE RowRef = @n_RowRef
      END	 
   END

   IF EXISTS (SELECT 1
              FROM PACKINFO PIF (NOLOCK)
              WHERE PIF.PickSlipNo = @c_PickSlipNo
              AND PIF.CartonNo = @n_CartonNo AND ISNULL(PIF.TrackingNo,'') = '') AND @n_CartonNo > 1   --WL04
   BEGIN
      SELECT TOP 1 @n_RowRef = CT.RowRef
                 , @c_CTNTrackNo = CT.TrackingNo
      FROM CARTONTRACK CT (NOLOCK)
      WHERE CT.LabelNo = @c_Orderkey
      --AND CT.CarrierRef2 = 'GET'
      AND CT.CarrierRef1 = @c_Orderkey + CAST(@n_CartonNo AS NVARCHAR)
      ORDER BY CT.AddDate

      UPDATE dbo.PACKINFO
      SET TrackingNo = @c_CTNTrackNo
      WHERE CartonNo = @n_CartonNo AND PickSlipNo = @c_PickSlipNo
   END

 --  IF ISNULL(@c_CTNTrackNo,'') = ''
 --  BEGIN
	--  SELECT TOP 1 @n_RowRef = CT.RowRef,
	--				@c_CTNTrackNo = CT.TrackingNo
	--  FROM CARTONTRACK CT (NOLOCK)
 --     WHERE CT.LabelNo = @c_Orderkey
 --     AND CT.CarrierRef1 = @c_Orderkey + CAST(@n_CartonNo AS NVARCHAR)
	--  ORDER BY CT.AddDate

	--  UPDATE dbo.PACKINFO
	--  SET TrackingNo = @c_CTNTrackNo
	--  WHERE RowRef =  @n_RowRef 
	--END

   --Prevent get trackingno for next carton if this is the last carton
   IF NOT EXISTS (SELECT 1 
                  FROM PACKTASKDETAIL  PTD WITH (NOLOCK)   
                  LEFT JOIN PACKDETAIL PD  WITH (NOLOCK) ON (PTD.PickSlipNo = PD.PickSlipNo)   
                                                         AND(PTD.Storerkey = PD.Storerkey)  
                                                         AND(PTD.Sku = PD.Sku)  
                  WHERE PTD.TaskBatchNo = @c_TaskBatchNo  
                  AND   PTD.Orderkey = @c_Orderkey    
                  GROUP  BY PTD.Orderkey  
                           ,PTD.Storerkey  
                           ,PTD.Sku  
                           ,PTD.QtyAllocated 
                  HAVING PTD.QtyAllocated -  ISNULL(SUM(PD.Qty),0) > 0  
                 )
   BEGIN
      GOTO QUIT_SP  
   END

   SEND_ITF: -- Send ITF to get Tracking # for Next CartonNo
   BEGIN TRAN
   
   --WL02 S
   --WL01 S
   --SELECT @c_Tablename = dbo.fnc_GetParamValueFromString('@c_Tablename', @c_Option5, 'WSCRPKADDCN')  

   --IF ISNULL(@c_Tablename, '') = ''
   --   SET @c_Tablename = 'WSCRPKADDCN' 

   --SELECT @c_DataStream = dbo.fnc_GetParamValueFromString('@c_DataStream', @c_Option5, '6157')  

   --IF ISNULL(@c_DataStream, '') = ''
   --   SET @c_DataStream = '6157' 
   --WL01 E

   SET @c_Tablename = ''
   SET @c_DataStream = ''
   
   SELECT @c_Tablename = dbo.fnc_GetParamValueFromString('@c_Tablename', @c_Option5, '') 
   SELECT @c_DataStream = dbo.fnc_GetParamValueFromString('@c_DataStream', @c_Option5, '')  

   IF ISNULL(@c_Tablename,'') = '' AND ISNULL(@c_DataStream,'') = ''
   BEGIN
      SELECT @c_ECPlatform_JSON = dbo.fnc_GetParamValueFromString('@c_ECPlatform_JSON', @c_Option5, '')  
      
      IF ISNULL(TRIM(@c_ECPlatform_JSON),'') <> ''
      BEGIN
         DECLARE @T TABLE (
              ECOM_Platform   NVARCHAR(100) NULL
            , Tablename       NVARCHAR(100) NULL
            , Datastream      NVARCHAR(100) NULL
         )
      
         INSERT INTO @T
         SELECT ECOM_Platform      
              , Tablename
              , Datastream          
         FROM
            OPENJSON(@c_ECPlatform_JSON)
            WITH (
            ECOM_Platform  NVARCHAR(100) '$.ECOM_Platform'
          , Tablename      NVARCHAR(100) '$.Tablename'
          , Datastream     NVARCHAR(100) '$.Datastream'
         )
         WHERE ECOM_Platform = @c_ECOMPlatform
      
         SELECT TOP 1 @c_TableName  = T.Tablename
                    , @c_DataStream = T.Datastream
         FROM @T T
      END
   END

   --WL03 S
   SET @c_TL2KeyPrefix = ''
   SELECT @c_TL2KeyPrefix = dbo.fnc_GetParamValueFromString('@c_TL2KeyPrefix', @c_Option5, '')  

   IF ISJSON(@c_TL2KeyPrefix) = 1
   BEGIN
      DECLARE @TL2 TABLE
      (
         [Column] NVARCHAR(10)  NULL
       , Prefix   NVARCHAR(100) NULL
      )

      INSERT INTO @TL2
      SELECT [Column]
           , Prefix
      FROM
         OPENJSON(@c_TL2KeyPrefix)
         WITH ([Column] NVARCHAR(10)  '$.Column'
             , Prefix   NVARCHAR(100) '$.Prefix')

      SELECT @c_Key1Prefix = CAST(T.Prefix AS NVARCHAR) FROM @TL2 T WHERE T.[Column] = 'Key1'
      SELECT @c_Key2Prefix = CAST(T.Prefix AS NVARCHAR) FROM @TL2 T WHERE T.[Column] = 'Key2'
      SELECT @c_Key3Prefix = CAST(T.Prefix AS NVARCHAR) FROM @TL2 T WHERE T.[Column] = 'Key3'
   END
   --WL03 E

   IF ISNULL(@c_Tablename, '') = ''
      SET @c_Tablename = 'WSCRPKADDCN' 

   IF ISNULL(@c_DataStream, '') = ''
      SET @c_DataStream = '6157' 
   --WL02 E

   SET @c_CartonNo = CONVERT(NVARCHAR(5), @n_CartonNo + 1)
   
   SET @c_TransmitlogKey = ''
   EXECUTE nspg_getkey  
     'TransmitlogKey2'  
     , 10  
     , @c_TransmitlogKey   OUTPUT  
     , @b_success          OUTPUT  
     , @n_err              OUTPUT  
     , @c_errmsg           OUTPUT  
  
   IF NOT @b_success = 1  
   BEGIN  
      SET @n_continue = 3  
      SET @c_errmsg = ERROR_MESSAGE()
      SET @n_Err=60020   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
      SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),@n_err)   
                        + ': Unable to Obtain transmitlogkey. (ispGenTransmitLog2) ( SQLSvr MESSAGE='   
                          + @c_errmsg + ' ) ' 
      GOTO QUIT_SP                  
   END  

   INSERT INTO TRANSMITLOG2 (transmitlogkey, tablename, key1, key2, key3, transmitflag, transmitbatch)
   VALUES (@c_TransmitlogKey, @c_TableName
         , CASE WHEN TRIM(ISNULL(@c_Key1Prefix, '')) = '' 
                THEN TRIM(@c_Orderkey)
                ELSE TRIM(ISNULL(@c_Key1Prefix, '')) + TRIM(@c_Orderkey) END    --WL03
         , CASE WHEN TRIM(ISNULL(@c_Key2Prefix, '')) = '' 
                THEN TRIM(@c_CartonNo)
                ELSE TRIM(ISNULL(@c_Key2Prefix, '')) + TRIM(@c_CartonNo) END    --WL03
         , CASE WHEN TRIM(ISNULL(@c_Key3Prefix, '')) = '' 
                THEN TRIM(@c_Storerkey)
                ELSE TRIM(ISNULL(@c_Key3Prefix, '')) + TRIM(@c_Storerkey) END   --WL03
         , '0', '')
   
   IF @@ERROR <> 0            
   BEGIN					  
      SET @n_continue = 3  
      SET @c_errmsg = ERROR_MESSAGE()   
      SET @n_err = 60030          
      SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0)) +           
                    + ': Insert into TRANSMITLOG2 Failed. (isp_EPackCtnTrack09) '
                    + '( SQLSvr MESSAGE = ' + @c_errmsg + ' ) '          
      GOTO QUIT_SP          
   END 
   
   --EXEC ispGenTransmitLog2 @c_Tablename, @c_OrderKey, @c_CartonNo, @c_StorerKey, ''          
   --                        , @b_success OUTPUT          
   --                        , @n_err OUTPUT          
   --                        , @c_errmsg OUTPUT          
                               
   --IF @b_success <> 1          
   --BEGIN          
   --   SET @n_continue = 3          
   --   SET @n_err = 60020          
   --   SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0)) +           
   --                 + ': Insert into TRANSMITLOG2 Failed. (isp_EPackCtnTrack09) '
   --                 + '( SQLSvr MESSAGE = ' + @c_errmsg + ' ) '          
   --   GOTO QUIT_SP          
   --END 
   
   --SET @c_TransmitlogKey = ''
         
   --SELECT TOP 1 @c_TransmitlogKey = t.transmitlogkey
   --FROM TRANSMITLOG2 AS t WITH(NOLOCK)
   --WHERE t.tablename = @c_TableName
   --AND t.key1 = @c_OrderKey
   --AND t.key2 = @c_CartonNo 
   --AND t.key3 = @c_StorerKey 
   --AND t.transmitflag = '0'
   --ORDER BY t.transmitlogkey DESC
         
   --IF @c_TransmitlogKey <> ''
   --BEGIN
      SELECT @c_Command = StoredProcName + ',@c_TransmitlogKey=''' + @c_TransmitlogKey + ''' ' 
            ,@c_IP = IP
            ,@c_Port = Port
            ,@n_ThreadPerAcct = ThreadPerAcct
            ,@n_MilisecondDelay = MilisecondDelay 
            ,@c_APP_DB_Name = App_DB_Name--TargetDB      
            ,@c_IniFilePath = IniFilePath                
            ,@n_ThreadPerStream = ThreadPerStream        
      FROM  QCmd_TransmitlogConfig WITH (NOLOCK)  
      WHERE DataStream = @c_DataStream 
         AND TableName = @c_TableName  
         AND StorerKey = @c_StorerKey

      BEGIN TRY    
         EXEC isp_QCmd_SubmitTaskToQCommander     
               @cTaskType        = 'T'-- D=By Datastream, T=Transmitlog, O=Others           
            ,  @cStorerKey       = @c_StorerKey                                                
            ,  @cDataStream      = @c_DataStream                                                         
            ,  @cCmdType         = 'SQL'                                                      
            ,  @cCommand         = @c_Command                                                  
            ,  @cTransmitlogKey  = @c_TransmitlogKey                                             
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
         SET @n_Continue=3 
         SET @n_err = 60040   
         SET @c_ErrMsg = ERROR_MESSAGE()
         SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0)) +           
                    + ': Error Executing isp_QCmd_SubmitTaskToQCommander. (isp_EPackCtnTrack09) '
                    + '( SQLSvr MESSAGE = ' + @c_errmsg + ' ) '    
         GOTO QUIT_SP 
      END CATCH 
   
      IF @n_Err <> 0 AND ISNULL(@c_ErrMsg,'') <> ''    
      BEGIN
      	SET @n_Continue=3 
         SET @n_err = 60050   
         SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0)) +           
                    + ': ' + @c_errmsg + '. (isp_EPackCtnTrack09) '
         GOTO QUIT_SP     
      END                 
   --END         
        
   WHILE @@TRANCOUNT > 0        
   BEGIN        
      COMMIT TRAN        
   END        
        
   QUIT_SP: 
   IF @b_Success = 1
   BEGIN
      --Check if b_SuccessOld = 2, if yes need to set b_success to 2, prevent ECOM Packing insert PackInfo
      IF @b_SuccessOld = 2
      BEGIN
         SET @b_Success = 2
      END
   END      
        
   IF @n_Continue=3  -- Error Occured - Process And Return        
   BEGIN        
      SET @b_Success = 0        
      IF @@TRANCOUNT > 0  
      BEGIN   
         ROLLBACK TRAN        
      END  
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_EPackCtnTrack09'        
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012        
   END        
        
   WHILE @@TRANCOUNT < @n_StartTCnt        
   BEGIN        
      BEGIN TRAN        
   END        
END -- procedure 

GO