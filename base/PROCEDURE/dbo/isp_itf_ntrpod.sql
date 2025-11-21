SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/  
/* Store Procedure:  isp_ITF_ntrPOD                                     */  
/* Creation Date: 12-Aug-2014                                           */  
/* Copyright: LF                                                        */  
/* Written by: MCTang                                                   */  
/*                                                                      */  
/* Purpose:  Handling trigger points for POD's module.                  */  
/*           Including POD trigger points for Add & Update.             */  
/*                                                                      */  
/* Output Parameters:  @b_Success                                       */  
/*                     @n_err                                           */  
/*                     @c_errmsg                                        */  
/*                                                                      */  
/* Return Status:  @b_Success = 0 or 1                                  */  
/*                                                                      */  
/* Usage:  StorerConfig & Trigger Points verification & update on       */  
/*         configuration table - ITFTriggerConfig.                      */  
/*                                                                      */  
/* Called By:  Trigger/Store Procedure.                                 */  
/*             - ntrPODAdd                                              */  
/*             - ntrPODUpdate                                           */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/* Date        Author   Ver.  Purposes                                  */  
/*01-Oct-2015  KTLow    1.0   Add Insert Transmitlog2 (KT01)            */  
/*24-Jan-2017  TLTING01 1.1   SET ANSI NULLS Option                     */
/*06-Sep-2022  YTKuek   1.2   Add GVTITF (YT01)                         */
/************************************************************************/  
  
CREATE PROC [dbo].[isp_ITF_ntrPOD]  
            @c_TriggerName          nvarchar(120)  
          , @c_SourceTable          nvarchar(60)  
          , @c_StorerKey            nvarchar(15)
          , @c_MBOLKey              nvarchar(10)  
          , @c_MBOLLineNumber       nvarchar(5)  
          , @b_ColumnsUpdated       VARBINARY(1000)
          , @b_Success              int           OUTPUT  
          , @n_err                  int           OUTPUT  
          , @c_errmsg               nvarchar(250) OUTPUT  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF      --tlting
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
/********************************************************/  
/* Variables Declaration & Initialization - (Start)     */  
/********************************************************/  
   DECLARE @n_Continue              int    
         , @n_StartTCnt             int     -- Holds the current transaction count  
  
   -- ITFTriggerConfig table  
   DECLARE @c_ConfigKey             nvarchar(30)  
         , @c_Tablename             nvarchar(30)  
         , @c_RecordType            nvarchar(10)  
         , @c_RecordStatus          nvarchar(10)  
         , @c_sValue                nvarchar(10)  
         , @c_TargetTable           nvarchar(60)  
         , @c_StoredProc            nvarchar(200)  
         , @c_ConfigFacility        nvarchar(5)
         , @c_UpdatedColumns        NVARCHAR(250)      
  
   -- ORDERS table  
   DECLARE @c_OrderKey              nvarchar(10)  
         , @c_Status                nvarchar(10)  
         , @c_Key1                  NVARCHAR(10)
         , @c_Key2                  NVARCHAR(5)
         , @c_FinalizeFlag          NVARCHAR(1)   

   --(YT01)-S
   DECLARE @dt_ActualDeliveryDate   DATETIME
         , @dt_InvDespatchDate      DATETIME
         , @dt_PodReceivedDate      DATETIME
         , @dt_PodFiledDate         DATETIME
         , @dt_InvCancelDate        DATETIME
         , @dt_RedeliveryDate       DATETIME
         , @dt_FullRejectDate       DATETIME
         , @dt_PartialRejectDate    DATETIME
         , @dt_PoisonFormDate       DATETIME
         , @dt_ChequeDate           DATETIME
         , @dt_PODDate01            DATETIME
         , @dt_PODDate02            DATETIME
         , @dt_PODDate03            DATETIME
         , @dt_PODDate04            DATETIME
         , @dt_PODDate05            DATETIME
         , @dt_TrackDate01          DATETIME
         , @dt_TrackDate02          DATETIME
         , @dt_TrackDate03          DATETIME
         , @dt_TrackDate04          DATETIME
         , @dt_TrackDate05          DATETIME
         , @c_ActualDeliveryDate    NVARCHAR(19)
         , @c_InvDespatchDate       NVARCHAR(19)
         , @c_PodReceivedDate       NVARCHAR(19)
         , @c_PodFiledDate          NVARCHAR(19)
         , @c_InvCancelDate         NVARCHAR(19)
         , @c_RedeliveryDate        NVARCHAR(19)
         , @c_FullRejectDate        NVARCHAR(19)
         , @c_PartialRejectDate     NVARCHAR(19)
         , @c_PoisonFormDate        NVARCHAR(19)
         , @c_ChequeDate            NVARCHAR(19)
         , @c_PODDate01             NVARCHAR(19)
         , @c_PODDate02             NVARCHAR(19)
         , @c_PODDate03             NVARCHAR(19)
         , @c_PODDate04             NVARCHAR(19)
         , @c_PODDate05             NVARCHAR(19)
         , @c_TrackDate01           NVARCHAR(19)
         , @c_TrackDate02           NVARCHAR(19)
         , @c_TrackDate03           NVARCHAR(19)
         , @c_TrackDate04           NVARCHAR(19)
         , @c_TrackDate05           NVARCHAR(19)
   --(YT01)-E
  
   SET @n_StartTCnt = @@TRANCOUNT   
   SET @n_Continue = 1   
   SET @b_success = 0   
   SET @n_err = 0   
   SET @c_errmsg = ''   

   --(YT01)-S
   SET @c_ActualDeliveryDate        = ''
   SET @c_InvDespatchDate           = ''
   SET @c_PodReceivedDate           = ''
   SET @c_PodFiledDate              = ''
   SET @c_InvCancelDate             = ''
   SET @c_RedeliveryDate            = ''
   SET @c_FullRejectDate            = ''
   SET @c_PartialRejectDate         = ''
   SET @c_PoisonFormDate            = ''
   SET @c_ChequeDate                = ''
   SET @c_PODDate01                 = ''
   SET @c_PODDate02                 = ''
   SET @c_PODDate03                 = ''
   SET @c_PODDate04                 = ''
   SET @c_PODDate05                 = ''
   SET @c_TrackDate01               = ''
   SET @c_TrackDate02               = ''
   SET @c_TrackDate03               = ''
   SET @c_TrackDate04               = ''
   SET @c_TrackDate05               = ''
   --(YT01)-E
/********************************************************/  
/* Variables Declaration & Initialization - (End)       */  
/********************************************************/  
  
/*************************************************************************************/  
/* Std - Verify Parameter variables, no values found, return to core program (Start) */  
/*************************************************************************************/  
   IF (ISNULL(RTRIM(@c_TriggerName),'') = '') OR   
      (ISNULL(RTRIM(@c_SourceTable),'') = '') OR         
      (ISNULL(RTRIM(@c_MBOLKey),'') = '')     OR
      (ISNULL(RTRIM(@c_MBOLLineNumber),'') = '')          
   BEGIN  
      RETURN  
   END  
  
   IF (ISNULL(RTRIM(@c_TriggerName),'') <> 'ntrPODUpdate')  
   BEGIN  
      IF (ISNULL(RTRIM(@c_TriggerName),'') <> 'ntrPODAdd')  
      BEGIN  
         RETURN  
      END  
   END  
  
   IF (ISNULL(RTRIM(@c_SourceTable),'') <> 'POD')  
   BEGIN  
      RETURN  
   END  
/*************************************************************************************/  
/* Std - Verify Parameter variables, no values found, return to core program (End)   */  
/*************************************************************************************/  
  
  
/*************************************************************************************/  
/* Std - Extract values for required variables (Start)                               */  
/*************************************************************************************/  
   IF @n_Continue = 1 OR @n_Continue = 2  
   BEGIN  
      SELECT @c_OrderKey            = ISNULL(RTRIM(POD.OrderKey),'')  
           , @c_Status              = ISNULL(RTRIM(POD.Status),'')   
           , @c_FinalizeFlag        = ISNULL(RTRIM(POD.FinalizeFlag),'')
           , @dt_ActualDeliveryDate = ActualDeliveryDate   --(YT01)
           , @dt_InvDespatchDate    = InvDespatchDate      --(YT01)
           , @dt_PodReceivedDate    = PodReceivedDate      --(YT01)
           , @dt_PodFiledDate       = PodFiledDate         --(YT01)
           , @dt_InvCancelDate      = InvCancelDate        --(YT01)
           , @dt_RedeliveryDate     = RedeliveryDate       --(YT01)
           , @dt_FullRejectDate     = FullRejectDate       --(YT01)
           , @dt_PartialRejectDate  = PartialRejectDate    --(YT01)
           , @dt_PoisonFormDate     = PoisonFormDate       --(YT01)
           , @dt_ChequeDate         = ChequeDate           --(YT01)
           , @dt_PODDate01          = PODDate01            --(YT01)
           , @dt_PODDate02          = PODDate02            --(YT01)
           , @dt_PODDate03          = PODDate03            --(YT01)
           , @dt_PODDate04          = PODDate04            --(YT01)
           , @dt_PODDate05          = PODDate05            --(YT01)
           , @dt_TrackDate01        = TrackDate01          --(YT01)
           , @dt_TrackDate02        = TrackDate02          --(YT01)
           , @dt_TrackDate03        = TrackDate03          --(YT01)
           , @dt_TrackDate04        = TrackDate04          --(YT01)
           , @dt_TrackDate05        = TrackDate05          --(YT01)
      FROM  POD WITH (NOLOCK)   
      WHERE POD.MBOLKey          = @c_MBOLKey  
      AND   POD.MBOLLineNumber   = @c_MBOLLineNumber
   END   
/*************************************************************************************/  
/* Std - Extract values for required variables (End)                                 */  
/*************************************************************************************/  
  
/********************************************/  
/* Main Program (Start)                     */  
/********************************************/  
   IF @n_Continue = 1 OR @n_Continue = 2  
   BEGIN  
      IF EXISTS ( SELECT 1 
                  FROM  ITFTriggerConfig WITH (NOLOCK)    
                  WHERE StorerKey   = @c_StorerKey   
                  AND   SourceTable = @c_SourceTable  
                  AND   sValue      = '1' )  
      BEGIN   
         DECLARE Cur_ITFTriggerConfig_Order CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
         SELECT DISTINCT  ConfigKey  
                        , Facility  
                        , Tablename  
                        , RecordType  
                        , RecordStatus  
                        , sValue  
                        , TargetTable  
                        , StoredProc
                        , UpdatedColumns  
         FROM  ITFTriggerConfig WITH (NOLOCK)   
         WHERE StorerKey   = @c_StorerKey    
         AND   SourceTable = @c_SourceTable  
         AND   sValue      = '1'  
  
         OPEN Cur_ITFTriggerConfig_Order  
         FETCH NEXT FROM Cur_ITFTriggerConfig_Order INTO   @c_ConfigKey
                                                         , @c_ConfigFacility
                                                         , @c_Tablename
                                                         , @c_RecordType
                                                         , @c_RecordStatus  
                                                         , @c_sValue
                                                         , @c_TargetTable
                                                         , @c_StoredProc
                                                         , @c_UpdatedColumns   
  
         WHILE @@FETCH_STATUS <> -1  
         BEGIN 
            --PRINT '@c_ConfigKey: ' + @c_ConfigKey
            --PRINT '@c_UpdatedColumns: ' + @c_UpdatedColumns  
            IF ISNULL(RTRIM(@c_UpdatedColumns), '') <> ''
            BEGIN
               IF NOT EXISTS(SELECT 1 FROM 
                             dbo.fnc_GetUpdatedColumns(@c_SourceTable, @b_ColumnsUpdated) 
                             WHERE COLUMN_NAME IN (
                                             SELECT ColValue 
                                             FROM dbo.fnc_DelimSplit(',', @c_UpdatedColumns)))
               BEGIN
                  --PRINT 'Not Exists, GET_NEXT_Record '
                  GOTO GET_NEXT_Record
               END 
            END
            
            SET @b_Success = 0

            IF ISNULL(RTRIM(@c_StoredProc),'') <> ''
            BEGIN
               EXEC sys.sp_executesql @c_StoredProc, N'@c_OrderKey NVARCHAR(10), @b_Success INT OUTPUT, @c_ErrNo INT OUTPUT, @c_ErrMsg NVARCHAR(215) OUTPUT',
                           @c_OrderKey, 
                           @b_Success OUTPUT, 
                           @n_err     OUTPUT, 
                           @c_errmsg  OUTPUT 
            END
            ELSE
            BEGIN
               IF (@c_RecordStatus <> '' AND (@c_RecordStatus = @c_Status)) OR
                  (@c_RecordStatus <> '' AND (@c_RecordStatus = @c_FinalizeFlag))
               BEGIN 
                  SET @b_Success = 1
               END 
            END

            IF @b_Success = 1
            BEGIN
               /*************************************************************************************/
               /* Records Insertion into selected TransmitLog table with StorerKey - (Start)        */
               /*************************************************************************************/
               IF @c_TargetTable = 'TRANSMITLOG3'
               BEGIN
                  EXEC ispGenTransmitLog3 @c_Tablename, @c_OrderKey, '', @c_StorerKey, ''
                                        , @b_success OUTPUT
                                        , @n_Err OUTPUT
                                        , @c_ErrMsg OUTPUT
                     
                  IF @b_success <> 1
                  BEGIN
                     SET @n_Continue = 3
                     SET @n_Err = 68001
                     SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_Err,0)) + 
                                     ': Insert into TRANSMITLOG3 Failed. (isp_ITF_ntrPOD) ( SQLSvr MESSAGE = ' + 
                                     ISNULL(LTRIM(RTRIM(@c_ErrMsg)),'') + ' ) '
                     GOTO QUIT
                  END 
               END -- IF @c_TargetTable = 'TRANSMITLOG3'

               --(KT01) - Start
               IF @c_TargetTable = 'TRANSMITLOG2'
               BEGIN
                  EXEC ispGenTransmitLog2 @c_Tablename, @c_OrderKey, @c_Status, @c_StorerKey, ''
                                        , @b_success OUTPUT
                                        , @n_Err OUTPUT
                                        , @c_ErrMsg OUTPUT
                     
                  IF @b_success <> 1
                  BEGIN
                     SET @n_Continue = 3
                     SET @n_Err = 68001
                     SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_Err,0)) + 
                                     ': Insert into TRANSMITLOG2 Failed. (isp_ITF_ntrPOD) ( SQLSvr MESSAGE = ' + 
                                     ISNULL(LTRIM(RTRIM(@c_ErrMsg)),'') + ' ) '
                     GOTO QUIT
                  END 
               END -- IF @c_TargetTable = 'TRANSMITLOG2'
               --(KT01) - End
               /*************************************************************************************/
               /* Records Insertion into selected TransmitLog table with StorerKey - (End)          */
               /*************************************************************************************/
            END  --IF @b_Success = 1
  
            GET_NEXT_Record:
            
            FETCH NEXT FROM Cur_ITFTriggerConfig_Order INTO   @c_ConfigKey
                                                            , @c_ConfigFacility
                                                            , @c_Tablename
                                                            , @c_RecordType
                                                            , @c_RecordStatus  
                                                            , @c_sValue
                                                            , @c_TargetTable
                                                            , @c_StoredProc
                                                            , @c_UpdatedColumns    
         END -- WHILE @@FETCH_STATUS <> -1  
         CLOSE Cur_ITFTriggerConfig_Order  
         DEALLOCATE Cur_ITFTriggerConfig_Order  
      END -- IF EXISTS @c_SourceTable     
   END -- IF @n_Continue = 1 OR @n_Continue = 2  

   --(YT01)-S
   IF @n_Continue = 1 OR @n_Continue = 2  
   BEGIN  
      /********************************************/    
      /* GVTITF (START)                           */    
      /********************************************/   
      IF EXISTS ( SELECT 1 FROM StorerConfig STC WITH (NOLOCK) 
                  WHERE STC.StorerKey = @c_Storerkey   
                  AND   STC.ConfigKey = 'GVTITF'  
                  AND   STC.SValue    = '1' )                       
      BEGIN  
         IF (ISNULL(RTRIM(@c_TriggerName),'') = 'ntrPODUpdate')  
         BEGIN
            --GVTEPODAPDD
            IF EXISTS(SELECT 1 
                      FROM dbo.fnc_GetUpdatedColumns(@c_SourceTable, @b_ColumnsUpdated) 
                      WHERE COLUMN_NAME IN (SELECT ColValue 
                                            FROM dbo.fnc_DelimSplit(',', 'ActualDeliveryDate')
                                            )
                     )
            BEGIN
               IF EXISTS ( SELECT 1 FROM StorerConfig STC WITH (NOLOCK)     
                           WHERE STC.StorerKey = @c_Storerkey   
                           AND   STC.ConfigKey = 'GVTEPODAPDD'  
                           AND   STC.SValue    = '1' )  
               BEGIN  
                  SET @c_ActualDeliveryDate = CONVERT(NVARCHAR(19),@dt_ActualDeliveryDate,120)

                  EXEC ispGenGVTLog 'GVTEPODAPDD', @c_OrderKey, @c_ActualDeliveryDate, @c_StorerKey, ''    
                                    , @b_success   OUTPUT    
                                    , @n_err       OUTPUT    
                                    , @c_errmsg    OUTPUT   
  
                  IF @b_success <> 1  
                  BEGIN  
                     SET @n_continue = 3  
                     GOTO QUIT   
                  END  
               END 
            END

            --GVTEPODAPID
            IF EXISTS(SELECT 1 
                      FROM dbo.fnc_GetUpdatedColumns(@c_SourceTable, @b_ColumnsUpdated) 
                      WHERE COLUMN_NAME IN (SELECT ColValue 
                                            FROM dbo.fnc_DelimSplit(',', 'InvDespatchDate')
                                            )
                     )
            BEGIN
               IF EXISTS ( SELECT 1 FROM StorerConfig STC WITH (NOLOCK)     
                           WHERE STC.StorerKey = @c_Storerkey   
                           AND   STC.ConfigKey = 'GVTEPODAPID'  
                           AND   STC.SValue    = '1' )  
               BEGIN  
                  SET @c_InvDespatchDate= CONVERT(NVARCHAR(19),@dt_InvDespatchDate,120)

                  EXEC ispGenGVTLog 'GVTEPODAPID', @c_OrderKey, @c_InvDespatchDate, @c_StorerKey, ''    
                                    , @b_success   OUTPUT    
                                    , @n_err       OUTPUT    
                                    , @c_errmsg    OUTPUT   
  
                  IF @b_success <> 1  
                  BEGIN  
                     SET @n_continue = 3  
                     GOTO QUIT   
                  END  
               END 
            END

            --GVTEPODAPRD
            IF EXISTS(SELECT 1 
                      FROM dbo.fnc_GetUpdatedColumns(@c_SourceTable, @b_ColumnsUpdated) 
                      WHERE COLUMN_NAME IN (SELECT ColValue 
                                            FROM dbo.fnc_DelimSplit(',', 'PodReceivedDate')
                                            )
                     )
            BEGIN
               IF EXISTS ( SELECT 1 FROM StorerConfig STC WITH (NOLOCK)     
                           WHERE STC.StorerKey = @c_Storerkey   
                           AND   STC.ConfigKey = 'GVTEPODAPRD'  
                           AND   STC.SValue    = '1' )  
               BEGIN  
                  SET @c_PodReceivedDate= CONVERT(NVARCHAR(19),@dt_PodReceivedDate,120)

                  EXEC ispGenGVTLog 'GVTEPODAPRD', @c_OrderKey, @c_PodReceivedDate, @c_StorerKey, ''    
                                    , @b_success   OUTPUT    
                                    , @n_err       OUTPUT    
                                    , @c_errmsg    OUTPUT   
  
                  IF @b_success <> 1  
                  BEGIN  
                     SET @n_continue = 3  
                     GOTO QUIT   
                  END  
               END 
            END

            --GVTEPODAPFD
            IF EXISTS(SELECT 1 
                      FROM dbo.fnc_GetUpdatedColumns(@c_SourceTable, @b_ColumnsUpdated) 
                      WHERE COLUMN_NAME IN (SELECT ColValue 
                                            FROM dbo.fnc_DelimSplit(',', 'PodFiledDate')
                                            )
                     )
            BEGIN
               IF EXISTS ( SELECT 1 FROM StorerConfig STC WITH (NOLOCK)     
                           WHERE STC.StorerKey = @c_Storerkey   
                           AND   STC.ConfigKey = 'GVTEPODAPFD'  
                           AND   STC.SValue    = '1' )  
               BEGIN  
                  SET @c_PodFiledDate= CONVERT(NVARCHAR(19),@dt_PodFiledDate,120)

                  EXEC ispGenGVTLog 'GVTEPODAPFD', @c_OrderKey, @c_PodFiledDate, @c_StorerKey, ''    
                                    , @b_success   OUTPUT    
                                    , @n_err       OUTPUT    
                                    , @c_errmsg    OUTPUT   
  
                  IF @b_success <> 1  
                  BEGIN  
                     SET @n_continue = 3  
                     GOTO QUIT   
                  END  
               END 
            END

            --GVTEPODAPCD
            IF EXISTS(SELECT 1 
                      FROM dbo.fnc_GetUpdatedColumns(@c_SourceTable, @b_ColumnsUpdated) 
                      WHERE COLUMN_NAME IN (SELECT ColValue 
                                            FROM dbo.fnc_DelimSplit(',', 'InvCancelDate')
                                            )
                     )
            BEGIN
               IF EXISTS ( SELECT 1 FROM StorerConfig STC WITH (NOLOCK)     
                           WHERE STC.StorerKey = @c_Storerkey   
                           AND   STC.ConfigKey = 'GVTEPODAPCD'  
                           AND   STC.SValue    = '1' )  
               BEGIN  
                  SET @c_InvCancelDate= CONVERT(NVARCHAR(19),@dt_InvCancelDate,120)

                  EXEC ispGenGVTLog 'GVTEPODAPCD', @c_OrderKey, @c_InvCancelDate, @c_StorerKey, ''    
                                    , @b_success   OUTPUT    
                                    , @n_err       OUTPUT    
                                    , @c_errmsg    OUTPUT   
  
                  IF @b_success <> 1  
                  BEGIN  
                     SET @n_continue = 3  
                     GOTO QUIT   
                  END  
               END 
            END

            --GVTEPODAPRL
            IF EXISTS(SELECT 1 
                      FROM dbo.fnc_GetUpdatedColumns(@c_SourceTable, @b_ColumnsUpdated) 
                      WHERE COLUMN_NAME IN (SELECT ColValue 
                                            FROM dbo.fnc_DelimSplit(',', 'RedeliveryDate')
                                            )
                     )
            BEGIN
               IF EXISTS ( SELECT 1 FROM StorerConfig STC WITH (NOLOCK)     
                           WHERE STC.StorerKey = @c_Storerkey   
                           AND   STC.ConfigKey = 'GVTEPODAPRL'  
                           AND   STC.SValue    = '1' )  
               BEGIN  
                  SET @c_RedeliveryDate= CONVERT(NVARCHAR(19),@dt_RedeliveryDate,120)

                  EXEC ispGenGVTLog 'GVTEPODAPRL', @c_OrderKey, @c_RedeliveryDate, @c_StorerKey, ''    
                                    , @b_success   OUTPUT    
                                    , @n_err       OUTPUT    
                                    , @c_errmsg    OUTPUT   
  
                  IF @b_success <> 1  
                  BEGIN  
                     SET @n_continue = 3  
                     GOTO QUIT   
                  END  
               END 
            END

            --GVTEPODAPFR
            IF EXISTS(SELECT 1 
                      FROM dbo.fnc_GetUpdatedColumns(@c_SourceTable, @b_ColumnsUpdated) 
                      WHERE COLUMN_NAME IN (SELECT ColValue 
                                            FROM dbo.fnc_DelimSplit(',', 'FullRejectDate')
                                            )
                     )
            BEGIN
               IF EXISTS ( SELECT 1 FROM StorerConfig STC WITH (NOLOCK)     
                           WHERE STC.StorerKey = @c_Storerkey   
                           AND   STC.ConfigKey = 'GVTEPODAPFR'  
                           AND   STC.SValue    = '1' )  
               BEGIN  
                  SET @c_FullRejectDate = CONVERT(NVARCHAR(19),@dt_FullRejectDate,120)

                  EXEC ispGenGVTLog 'GVTEPODAPFR', @c_OrderKey, @c_FullRejectDate, @c_StorerKey, ''    
                                    , @b_success   OUTPUT    
                                    , @n_err       OUTPUT    
                                    , @c_errmsg    OUTPUT   
  
                  IF @b_success <> 1  
                  BEGIN  
                     SET @n_continue = 3  
                     GOTO QUIT   
                  END  
               END 
            END

            --GVTEPODAPPR
            IF EXISTS(SELECT 1 
                      FROM dbo.fnc_GetUpdatedColumns(@c_SourceTable, @b_ColumnsUpdated) 
                      WHERE COLUMN_NAME IN (SELECT ColValue 
                                            FROM dbo.fnc_DelimSplit(',', 'PartialRejectDate')
                                            )
                     )
            BEGIN
               IF EXISTS ( SELECT 1 FROM StorerConfig STC WITH (NOLOCK)     
                           WHERE STC.StorerKey = @c_Storerkey   
                           AND   STC.ConfigKey = 'GVTEPODAPPR'  
                           AND   STC.SValue    = '1' )  
               BEGIN  
                  SET @c_PartialRejectDate = CONVERT(NVARCHAR(19),@dt_PartialRejectDate,120)

                  EXEC ispGenGVTLog 'GVTEPODAPPR', @c_OrderKey, @c_PartialRejectDate, @c_StorerKey, ''    
                                    , @b_success   OUTPUT    
                                    , @n_err       OUTPUT    
                                    , @c_errmsg    OUTPUT   
  
                  IF @b_success <> 1  
                  BEGIN  
                     SET @n_continue = 3  
                     GOTO QUIT   
                  END  
               END 
            END

            --GVTEPODAPPF
            IF EXISTS(SELECT 1 
                      FROM dbo.fnc_GetUpdatedColumns(@c_SourceTable, @b_ColumnsUpdated) 
                      WHERE COLUMN_NAME IN (SELECT ColValue 
                                            FROM dbo.fnc_DelimSplit(',', 'PoisonFormDate')
                                            )
                     )
            BEGIN
               IF EXISTS ( SELECT 1 FROM StorerConfig STC WITH (NOLOCK)     
                           WHERE STC.StorerKey = @c_Storerkey   
                           AND   STC.ConfigKey = 'GVTEPODAPPF'  
                           AND   STC.SValue    = '1' )  
               BEGIN  
                  SET @c_PoisonFormDate = CONVERT(NVARCHAR(19),@dt_PoisonFormDate,120)

                  EXEC ispGenGVTLog 'GVTEPODAPPF', @c_OrderKey, @c_PoisonFormDate, @c_StorerKey, ''    
                                    , @b_success   OUTPUT    
                                    , @n_err       OUTPUT    
                                    , @c_errmsg    OUTPUT   
  
                  IF @b_success <> 1  
                  BEGIN  
                     SET @n_continue = 3  
                     GOTO QUIT   
                  END  
               END 
            END

            --GVTEPODAPCQ
            IF EXISTS(SELECT 1 
                      FROM dbo.fnc_GetUpdatedColumns(@c_SourceTable, @b_ColumnsUpdated) 
                      WHERE COLUMN_NAME IN (SELECT ColValue 
                                            FROM dbo.fnc_DelimSplit(',', 'ChequeDate')
                                            )
                     )
            BEGIN
               IF EXISTS ( SELECT 1 FROM StorerConfig STC WITH (NOLOCK)     
                           WHERE STC.StorerKey = @c_Storerkey   
                           AND   STC.ConfigKey = 'GVTEPODAPCQ'  
                           AND   STC.SValue    = '1' )  
               BEGIN  
                  SET @c_ChequeDate = CONVERT(NVARCHAR(19),@dt_ChequeDate,120)

                  EXEC ispGenGVTLog 'GVTEPODAPCQ', @c_OrderKey, @c_ChequeDate, @c_StorerKey, ''    
                                    , @b_success   OUTPUT    
                                    , @n_err       OUTPUT    
                                    , @c_errmsg    OUTPUT   
  
                  IF @b_success <> 1  
                  BEGIN  
                     SET @n_continue = 3  
                     GOTO QUIT   
                  END  
               END 
            END

            --GVTEPODAPD1
            IF EXISTS(SELECT 1 
                      FROM dbo.fnc_GetUpdatedColumns(@c_SourceTable, @b_ColumnsUpdated) 
                      WHERE COLUMN_NAME IN (SELECT ColValue 
                                            FROM dbo.fnc_DelimSplit(',', 'PODDate01')
                                            )
                     )
            BEGIN
               IF EXISTS ( SELECT 1 FROM StorerConfig STC WITH (NOLOCK)     
                           WHERE STC.StorerKey = @c_Storerkey   
                           AND   STC.ConfigKey = 'GVTEPODAPD1'  
                           AND   STC.SValue    = '1' )  
               BEGIN  
                  SET @c_PODDate01 = CONVERT(NVARCHAR(19),@dt_PODDate01,120)

                  EXEC ispGenGVTLog 'GVTEPODAPD1', @c_OrderKey, @c_PODDate01, @c_StorerKey, ''    
                                    , @b_success   OUTPUT    
                                    , @n_err       OUTPUT    
                                    , @c_errmsg    OUTPUT   
  
                  IF @b_success <> 1  
                  BEGIN  
                     SET @n_continue = 3  
                     GOTO QUIT   
                  END  
               END 
            END

            --GVTEPODAPD2
            IF EXISTS(SELECT 1 
                      FROM dbo.fnc_GetUpdatedColumns(@c_SourceTable, @b_ColumnsUpdated) 
                      WHERE COLUMN_NAME IN (SELECT ColValue 
                                            FROM dbo.fnc_DelimSplit(',', 'PODDate02')
                                            )
                     )
            BEGIN
               IF EXISTS ( SELECT 1 FROM StorerConfig STC WITH (NOLOCK)     
                           WHERE STC.StorerKey = @c_Storerkey   
                           AND   STC.ConfigKey = 'GVTEPODAPD2'  
                           AND   STC.SValue    = '1' )  
               BEGIN  
                  SET @c_PODDate02 = CONVERT(NVARCHAR(19),@dt_PODDate02,120)

                  EXEC ispGenGVTLog 'GVTEPODAPD2', @c_OrderKey, @c_PODDate02, @c_StorerKey, ''    
                                    , @b_success   OUTPUT    
                                    , @n_err       OUTPUT    
                                    , @c_errmsg    OUTPUT   
  
                  IF @b_success <> 1  
                  BEGIN  
                     SET @n_continue = 3  
                     GOTO QUIT   
                  END  
               END 
            END

            --GVTEPODAPD3
            IF EXISTS(SELECT 1 
                      FROM dbo.fnc_GetUpdatedColumns(@c_SourceTable, @b_ColumnsUpdated) 
                      WHERE COLUMN_NAME IN (SELECT ColValue 
                                            FROM dbo.fnc_DelimSplit(',', 'PODDate03')
                                            )
                     )
            BEGIN
               IF EXISTS ( SELECT 1 FROM StorerConfig STC WITH (NOLOCK)     
                           WHERE STC.StorerKey = @c_Storerkey   
                           AND   STC.ConfigKey = 'GVTEPODAPD3'  
                           AND   STC.SValue    = '1' )  
               BEGIN  
                  SET @c_PODDate03 = CONVERT(NVARCHAR(19),@dt_PODDate03,120)

                  EXEC ispGenGVTLog 'GVTEPODAPD3', @c_OrderKey, @c_PODDate03, @c_StorerKey, ''    
                                    , @b_success   OUTPUT    
                                    , @n_err       OUTPUT    
                                    , @c_errmsg    OUTPUT   
  
                  IF @b_success <> 1  
                  BEGIN  
                     SET @n_continue = 3  
                     GOTO QUIT   
                  END  
               END 
            END

            --GVTEPODAPD4
            IF EXISTS(SELECT 1 
                      FROM dbo.fnc_GetUpdatedColumns(@c_SourceTable, @b_ColumnsUpdated) 
                      WHERE COLUMN_NAME IN (SELECT ColValue 
                                            FROM dbo.fnc_DelimSplit(',', 'PODDate04')
                                            )
                     )
            BEGIN
               IF EXISTS ( SELECT 1 FROM StorerConfig STC WITH (NOLOCK)     
                           WHERE STC.StorerKey = @c_Storerkey   
                           AND   STC.ConfigKey = 'GVTEPODAPD4'  
                           AND   STC.SValue    = '1' )  
               BEGIN  
                  SET @c_PODDate04 = CONVERT(NVARCHAR(19),@dt_PODDate04,120)

                  EXEC ispGenGVTLog 'GVTEPODAPD4', @c_OrderKey, @c_PODDate04, @c_StorerKey, ''    
                                    , @b_success   OUTPUT    
                                    , @n_err       OUTPUT    
                                    , @c_errmsg    OUTPUT   
  
                  IF @b_success <> 1  
                  BEGIN  
                     SET @n_continue = 3  
                     GOTO QUIT   
                  END  
               END 
            END

            --GVTEPODAPD5
            IF EXISTS(SELECT 1 
                      FROM dbo.fnc_GetUpdatedColumns(@c_SourceTable, @b_ColumnsUpdated) 
                      WHERE COLUMN_NAME IN (SELECT ColValue 
                                            FROM dbo.fnc_DelimSplit(',', 'PODDate05')
                                            )
                     )
            BEGIN
               IF EXISTS ( SELECT 1 FROM StorerConfig STC WITH (NOLOCK)     
                           WHERE STC.StorerKey = @c_Storerkey   
                           AND   STC.ConfigKey = 'GVTEPODAPD5'  
                           AND   STC.SValue    = '1' )  
               BEGIN  
                  SET @c_PODDate05 = CONVERT(NVARCHAR(19),@dt_PODDate05,120)

                  EXEC ispGenGVTLog 'GVTEPODAPD5', @c_OrderKey, @c_PODDate05, @c_StorerKey, ''    
                                    , @b_success   OUTPUT    
                                    , @n_err       OUTPUT    
                                    , @c_errmsg    OUTPUT   
  
                  IF @b_success <> 1  
                  BEGIN  
                     SET @n_continue = 3  
                     GOTO QUIT   
                  END  
               END 
            END

            --GVTEPODAPT1
            IF EXISTS(SELECT 1 
                      FROM dbo.fnc_GetUpdatedColumns(@c_SourceTable, @b_ColumnsUpdated) 
                      WHERE COLUMN_NAME IN (SELECT ColValue 
                                            FROM dbo.fnc_DelimSplit(',', 'TrackDate01')
                                            )
                     )
            BEGIN
               IF EXISTS ( SELECT 1 FROM StorerConfig STC WITH (NOLOCK)     
                           WHERE STC.StorerKey = @c_Storerkey   
                           AND   STC.ConfigKey = 'GVTEPODAPT1'  
                           AND   STC.SValue    = '1' )  
               BEGIN  
                  SET @c_TrackDate01 = CONVERT(NVARCHAR(19),@dt_TrackDate01,120)

                  EXEC ispGenGVTLog 'GVTEPODAPT1', @c_OrderKey, @c_TrackDate01, @c_StorerKey, ''    
                                    , @b_success   OUTPUT    
                                    , @n_err       OUTPUT    
                                    , @c_errmsg    OUTPUT   
  
                  IF @b_success <> 1  
                  BEGIN  
                     SET @n_continue = 3  
                     GOTO QUIT   
                  END  
               END 
            END

            --GVTEPODAPT2
            IF EXISTS(SELECT 1 
                      FROM dbo.fnc_GetUpdatedColumns(@c_SourceTable, @b_ColumnsUpdated) 
                      WHERE COLUMN_NAME IN (SELECT ColValue 
                                            FROM dbo.fnc_DelimSplit(',', 'TrackDate02')
                                            )
                     )
            BEGIN
               IF EXISTS ( SELECT 1 FROM StorerConfig STC WITH (NOLOCK)     
                           WHERE STC.StorerKey = @c_Storerkey   
                           AND   STC.ConfigKey = 'GVTEPODAPT2'  
                           AND   STC.SValue    = '1' )  
               BEGIN  
                  SET @c_TrackDate02 = CONVERT(NVARCHAR(19),@dt_TrackDate02,120)

                  EXEC ispGenGVTLog 'GVTEPODAPT2', @c_OrderKey, @c_TrackDate02, @c_StorerKey, ''    
                                    , @b_success   OUTPUT    
                                    , @n_err       OUTPUT    
                                    , @c_errmsg    OUTPUT   
  
                  IF @b_success <> 1  
                  BEGIN  
                     SET @n_continue = 3  
                     GOTO QUIT   
                  END  
               END 
            END

            --GVTEPODAPT3
            IF EXISTS(SELECT 1 
                      FROM dbo.fnc_GetUpdatedColumns(@c_SourceTable, @b_ColumnsUpdated) 
                      WHERE COLUMN_NAME IN (SELECT ColValue 
                                            FROM dbo.fnc_DelimSplit(',', 'TrackDate03')
                                            )
                     )
            BEGIN
               IF EXISTS ( SELECT 1 FROM StorerConfig STC WITH (NOLOCK)     
                           WHERE STC.StorerKey = @c_Storerkey   
                           AND   STC.ConfigKey = 'GVTEPODAPT3'  
                           AND   STC.SValue    = '1' )  
               BEGIN  
                  SET @c_TrackDate03 = CONVERT(NVARCHAR(19),@dt_TrackDate03,120)

                  EXEC ispGenGVTLog 'GVTEPODAPT3', @c_OrderKey, @c_TrackDate03, @c_StorerKey, ''    
                                    , @b_success   OUTPUT    
                                    , @n_err       OUTPUT    
                                    , @c_errmsg    OUTPUT   
  
                  IF @b_success <> 1  
                  BEGIN  
                     SET @n_continue = 3  
                     GOTO QUIT   
                  END  
               END 
            END

            --GVTEPODAPT4
            IF EXISTS(SELECT 1 
                      FROM dbo.fnc_GetUpdatedColumns(@c_SourceTable, @b_ColumnsUpdated) 
                      WHERE COLUMN_NAME IN (SELECT ColValue 
                                            FROM dbo.fnc_DelimSplit(',', 'TrackDate04')
                                            )
                     )
            BEGIN
               IF EXISTS ( SELECT 1 FROM StorerConfig STC WITH (NOLOCK)     
                           WHERE STC.StorerKey = @c_Storerkey   
                           AND   STC.ConfigKey = 'GVTEPODAPT4'  
                           AND   STC.SValue    = '1' )  
               BEGIN  
                  SET @c_TrackDate04 = CONVERT(NVARCHAR(19),@dt_TrackDate04,120)

                  EXEC ispGenGVTLog 'GVTEPODAPT4', @c_OrderKey, @c_TrackDate04, @c_StorerKey, ''    
                                    , @b_success   OUTPUT    
                                    , @n_err       OUTPUT    
                                    , @c_errmsg    OUTPUT   
  
                  IF @b_success <> 1  
                  BEGIN  
                     SET @n_continue = 3  
                     GOTO QUIT   
                  END  
               END 
            END

            --GVTEPODAPT5
            IF EXISTS(SELECT 1 
                      FROM dbo.fnc_GetUpdatedColumns(@c_SourceTable, @b_ColumnsUpdated) 
                      WHERE COLUMN_NAME IN (SELECT ColValue 
                                            FROM dbo.fnc_DelimSplit(',', 'TrackDate05')
                                            )
                     )
            BEGIN
               IF EXISTS ( SELECT 1 FROM StorerConfig STC WITH (NOLOCK)     
                           WHERE STC.StorerKey = @c_Storerkey   
                           AND   STC.ConfigKey = 'GVTEPODAPT5'  
                           AND   STC.SValue    = '1' )  
               BEGIN  
                  SET @c_TrackDate05 = CONVERT(NVARCHAR(19),@dt_TrackDate05,120)

                  EXEC ispGenGVTLog 'GVTEPODAPT5', @c_OrderKey, @c_TrackDate05, @c_StorerKey, ''    
                                    , @b_success   OUTPUT    
                                    , @n_err       OUTPUT    
                                    , @c_errmsg    OUTPUT   
  
                  IF @b_success <> 1  
                  BEGIN  
                     SET @n_continue = 3  
                     GOTO QUIT   
                  END  
               END 
            END
         END
         ELSE IF (ISNULL(RTRIM(@c_TriggerName),'') = 'ntrPODAdd')  
         BEGIN
            --GVTEPODAPDD
            IF EXISTS ( SELECT 1 FROM StorerConfig STC WITH (NOLOCK)     
                        WHERE STC.StorerKey = @c_Storerkey   
                        AND   STC.ConfigKey = 'GVTEPODAPDD'  
                        AND   STC.SValue    = '1' )  
            BEGIN
               IF @dt_ActualDeliveryDate <> NULL
               BEGIN
                  SET @c_ActualDeliveryDate = CONVERT(NVARCHAR(19),@dt_ActualDeliveryDate,120)

                  EXEC ispGenGVTLog 'GVTEPODAPDD', @c_OrderKey, @c_ActualDeliveryDate, @c_StorerKey, ''    
                                    , @b_success   OUTPUT    
                                    , @n_err       OUTPUT    
                                    , @c_errmsg    OUTPUT   
  
                  IF @b_success <> 1  
                  BEGIN  
                     SET @n_continue = 3  
                     GOTO QUIT   
                  END  
               END
            END

            --GVTEPODAPID
            IF EXISTS ( SELECT 1 FROM StorerConfig STC WITH (NOLOCK)     
                        WHERE STC.StorerKey = @c_Storerkey   
                        AND   STC.ConfigKey = 'GVTEPODAPID'  
                        AND   STC.SValue    = '1' )  
            BEGIN  
               IF @dt_InvDespatchDate <> NULL
               BEGIN
                  SET @c_InvDespatchDate= CONVERT(NVARCHAR(19),@dt_InvDespatchDate,120)

                  EXEC ispGenGVTLog 'GVTEPODAPID', @c_OrderKey, @c_InvDespatchDate, @c_StorerKey, ''    
                                    , @b_success   OUTPUT    
                                    , @n_err       OUTPUT    
                                    , @c_errmsg    OUTPUT   
  
                  IF @b_success <> 1  
                  BEGIN  
                     SET @n_continue = 3  
                     GOTO QUIT   
                  END  
               END
            END 


            --GVTEPODAPRD
            IF EXISTS ( SELECT 1 FROM StorerConfig STC WITH (NOLOCK)     
                        WHERE STC.StorerKey = @c_Storerkey   
                        AND   STC.ConfigKey = 'GVTEPODAPRD'  
                        AND   STC.SValue    = '1' )  
            BEGIN  
               IF @dt_PodReceivedDate <> NULL
               BEGIN
                  SET @c_PodReceivedDate= CONVERT(NVARCHAR(19),@dt_PodReceivedDate,120)

                  EXEC ispGenGVTLog 'GVTEPODAPRD', @c_OrderKey, @c_PodReceivedDate, @c_StorerKey, ''    
                                    , @b_success   OUTPUT    
                                    , @n_err       OUTPUT    
                                    , @c_errmsg    OUTPUT   
  
                  IF @b_success <> 1  
                  BEGIN  
                     SET @n_continue = 3  
                     GOTO QUIT   
                  END  
               END
            END 

            --GVTEPODAPFD
            IF EXISTS ( SELECT 1 FROM StorerConfig STC WITH (NOLOCK)     
                        WHERE STC.StorerKey = @c_Storerkey   
                        AND   STC.ConfigKey = 'GVTEPODAPFD'  
                        AND   STC.SValue    = '1' )  
            BEGIN  
               IF @dt_PodFiledDate <> NULL
               BEGIN
                  SET @c_PodFiledDate= CONVERT(NVARCHAR(19),@dt_PodFiledDate,120)

                  EXEC ispGenGVTLog 'GVTEPODAPFD', @c_OrderKey, @c_PodFiledDate, @c_StorerKey, ''    
                                    , @b_success   OUTPUT    
                                    , @n_err       OUTPUT    
                                    , @c_errmsg    OUTPUT   
  
                  IF @b_success <> 1  
                  BEGIN  
                     SET @n_continue = 3  
                     GOTO QUIT   
                  END  
               END
            END 

            --GVTEPODAPCD
            IF EXISTS ( SELECT 1 FROM StorerConfig STC WITH (NOLOCK)     
                        WHERE STC.StorerKey = @c_Storerkey   
                        AND   STC.ConfigKey = 'GVTEPODAPCD'  
                        AND   STC.SValue    = '1' )  
            BEGIN  
               IF @dt_InvCancelDate <> NULL
               BEGIN
                  SET @c_InvCancelDate= CONVERT(NVARCHAR(19),@dt_InvCancelDate,120)

                  EXEC ispGenGVTLog 'GVTEPODAPCD', @c_OrderKey, @c_InvCancelDate, @c_StorerKey, ''    
                                    , @b_success   OUTPUT    
                                    , @n_err       OUTPUT    
                                    , @c_errmsg    OUTPUT   
  
                  IF @b_success <> 1  
                  BEGIN  
                     SET @n_continue = 3  
                     GOTO QUIT   
                  END  
               END
            END 


            --GVTEPODAPRL
            IF EXISTS ( SELECT 1 FROM StorerConfig STC WITH (NOLOCK)     
                        WHERE STC.StorerKey = @c_Storerkey   
                        AND   STC.ConfigKey = 'GVTEPODAPRL'  
                        AND   STC.SValue    = '1' )  
            BEGIN  
               IF @dt_RedeliveryDate <> NULL
               BEGIN
                  SET @c_RedeliveryDate= CONVERT(NVARCHAR(19),@dt_RedeliveryDate,120)

                  EXEC ispGenGVTLog 'GVTEPODAPRL', @c_OrderKey, @c_RedeliveryDate, @c_StorerKey, ''    
                                    , @b_success   OUTPUT    
                                    , @n_err       OUTPUT    
                                    , @c_errmsg    OUTPUT   
  
                  IF @b_success <> 1  
                  BEGIN  
                     SET @n_continue = 3  
                     GOTO QUIT   
                  END  
               END
            END 

            --GVTEPODAPFR
            IF EXISTS ( SELECT 1 FROM StorerConfig STC WITH (NOLOCK)     
                        WHERE STC.StorerKey = @c_Storerkey   
                        AND   STC.ConfigKey = 'GVTEPODAPFR'  
                        AND   STC.SValue    = '1' )  
            BEGIN  
               IF @dt_FullRejectDate <> NULL
               BEGIN
                  SET @c_FullRejectDate = CONVERT(NVARCHAR(19),@dt_FullRejectDate,120)

                  EXEC ispGenGVTLog 'GVTEPODAPFR', @c_OrderKey, @c_FullRejectDate, @c_StorerKey, ''    
                                    , @b_success   OUTPUT    
                                    , @n_err       OUTPUT    
                                    , @c_errmsg    OUTPUT   
  
                  IF @b_success <> 1  
                  BEGIN  
                     SET @n_continue = 3  
                     GOTO QUIT   
                  END  
               END
            END 

            --GVTEPODAPPR
            IF EXISTS ( SELECT 1 FROM StorerConfig STC WITH (NOLOCK)     
                        WHERE STC.StorerKey = @c_Storerkey   
                        AND   STC.ConfigKey = 'GVTEPODAPPR'  
                        AND   STC.SValue    = '1' )  
            BEGIN  
               IF @dt_PartialRejectDate <> NULL
               BEGIN
                  SET @c_PartialRejectDate = CONVERT(NVARCHAR(19),@dt_PartialRejectDate,120)

                  EXEC ispGenGVTLog 'GVTEPODAPPR', @c_OrderKey, @c_PartialRejectDate, @c_StorerKey, ''    
                                    , @b_success   OUTPUT    
                                    , @n_err       OUTPUT    
                                    , @c_errmsg    OUTPUT   
  
                  IF @b_success <> 1  
                  BEGIN  
                     SET @n_continue = 3  
                     GOTO QUIT   
                  END  
               END
            END 

            --GVTEPODAPPF
            IF EXISTS ( SELECT 1 FROM StorerConfig STC WITH (NOLOCK)     
                        WHERE STC.StorerKey = @c_Storerkey   
                        AND   STC.ConfigKey = 'GVTEPODAPPF'  
                        AND   STC.SValue    = '1' )  
            BEGIN 
               IF @dt_PoisonFormDate <> NULL
               BEGIN
                  SET @c_PoisonFormDate = CONVERT(NVARCHAR(19),@dt_PoisonFormDate,120)

                  EXEC ispGenGVTLog 'GVTEPODAPPF', @c_OrderKey, @c_PoisonFormDate, @c_StorerKey, ''    
                                    , @b_success   OUTPUT    
                                    , @n_err       OUTPUT    
                                    , @c_errmsg    OUTPUT   
  
                  IF @b_success <> 1  
                  BEGIN  
                     SET @n_continue = 3  
                     GOTO QUIT   
                  END  
               END
            END 

            --GVTEPODAPCQ
            IF EXISTS ( SELECT 1 FROM StorerConfig STC WITH (NOLOCK)     
                        WHERE STC.StorerKey = @c_Storerkey   
                        AND   STC.ConfigKey = 'GVTEPODAPCQ'  
                        AND   STC.SValue    = '1' )  
            BEGIN  
               IF @dt_ChequeDate <> NULL
               BEGIN
                  SET @c_ChequeDate = CONVERT(NVARCHAR(19),@dt_ChequeDate,120)

                  EXEC ispGenGVTLog 'GVTEPODAPCQ', @c_OrderKey, @c_ChequeDate, @c_StorerKey, ''    
                                    , @b_success   OUTPUT    
                                    , @n_err       OUTPUT    
                                    , @c_errmsg    OUTPUT   
  
                  IF @b_success <> 1  
                  BEGIN  
                     SET @n_continue = 3  
                     GOTO QUIT   
                  END  
               END
            END 

            --GVTEPODAPD1
            IF EXISTS ( SELECT 1 FROM StorerConfig STC WITH (NOLOCK)     
                        WHERE STC.StorerKey = @c_Storerkey   
                        AND   STC.ConfigKey = 'GVTEPODAPD1'  
                        AND   STC.SValue    = '1' )  
            BEGIN  
               IF @dt_PODDate01 <> NULL
               BEGIN
                  SET @c_PODDate01 = CONVERT(NVARCHAR(19),@dt_PODDate01,120)

                  EXEC ispGenGVTLog 'GVTEPODAPD1', @c_OrderKey, @c_PODDate01, @c_StorerKey, ''    
                                    , @b_success   OUTPUT    
                                    , @n_err       OUTPUT    
                                    , @c_errmsg    OUTPUT   
  
                  IF @b_success <> 1  
                  BEGIN  
                     SET @n_continue = 3  
                     GOTO QUIT   
                  END  
               END
            END 

            --GVTEPODAPD2
            IF EXISTS ( SELECT 1 FROM StorerConfig STC WITH (NOLOCK)     
                        WHERE STC.StorerKey = @c_Storerkey   
                        AND   STC.ConfigKey = 'GVTEPODAPD2'  
                        AND   STC.SValue    = '1' )  
            BEGIN  
               IF @dt_PODDate02 <> NULL
               BEGIN
                  SET @c_PODDate02 = CONVERT(NVARCHAR(19),@dt_PODDate02,120)

                  EXEC ispGenGVTLog 'GVTEPODAPD2', @c_OrderKey, @c_PODDate02, @c_StorerKey, ''    
                                    , @b_success   OUTPUT    
                                    , @n_err       OUTPUT    
                                    , @c_errmsg    OUTPUT   
  
                  IF @b_success <> 1  
                  BEGIN  
                     SET @n_continue = 3  
                     GOTO QUIT   
                  END  
               END
            END 

            --GVTEPODAPD3
            IF EXISTS ( SELECT 1 FROM StorerConfig STC WITH (NOLOCK)     
                        WHERE STC.StorerKey = @c_Storerkey   
                        AND   STC.ConfigKey = 'GVTEPODAPD3'  
                        AND   STC.SValue    = '1' )  
            BEGIN
               IF @dt_PODDate03 <> NULL
               BEGIN
                  SET @c_PODDate03 = CONVERT(NVARCHAR(19),@dt_PODDate03,120)

                  EXEC ispGenGVTLog 'GVTEPODAPD3', @c_OrderKey, @c_PODDate03, @c_StorerKey, ''    
                                    , @b_success   OUTPUT    
                                    , @n_err       OUTPUT    
                                    , @c_errmsg    OUTPUT   
  
                  IF @b_success <> 1  
                  BEGIN  
                     SET @n_continue = 3  
                     GOTO QUIT   
                  END  
               END
            END 

            --GVTEPODAPD4
            IF EXISTS ( SELECT 1 FROM StorerConfig STC WITH (NOLOCK)     
                        WHERE STC.StorerKey = @c_Storerkey   
                        AND   STC.ConfigKey = 'GVTEPODAPD4'  
                        AND   STC.SValue    = '1' )  
            BEGIN  
               IF @dt_PODDate04 <> NULL
               BEGIN
                  SET @c_PODDate04 = CONVERT(NVARCHAR(19),@dt_PODDate04,120)

                  EXEC ispGenGVTLog 'GVTEPODAPD4', @c_OrderKey, @c_PODDate04, @c_StorerKey, ''    
                                    , @b_success   OUTPUT    
                                    , @n_err       OUTPUT    
                                    , @c_errmsg    OUTPUT   
  
                  IF @b_success <> 1  
                  BEGIN  
                     SET @n_continue = 3  
                     GOTO QUIT   
                  END 
               END 
            END 

            --GVTEPODAPD5
            IF EXISTS ( SELECT 1 FROM StorerConfig STC WITH (NOLOCK)     
                        WHERE STC.StorerKey = @c_Storerkey   
                        AND   STC.ConfigKey = 'GVTEPODAPD5'  
                        AND   STC.SValue    = '1' )  
            BEGIN  
               IF @dt_PODDate05 <> NULL
               BEGIN
                  SET @c_PODDate05 = CONVERT(NVARCHAR(19),@dt_PODDate05,120)

                  EXEC ispGenGVTLog 'GVTEPODAPD5', @c_OrderKey, @c_PODDate05, @c_StorerKey, ''    
                                    , @b_success   OUTPUT    
                                    , @n_err       OUTPUT    
                                    , @c_errmsg    OUTPUT   
  
                  IF @b_success <> 1  
                  BEGIN  
                     SET @n_continue = 3  
                     GOTO QUIT   
                  END  
               END
            END 

            --GVTEPODAPT1
            IF EXISTS ( SELECT 1 FROM StorerConfig STC WITH (NOLOCK)     
                        WHERE STC.StorerKey = @c_Storerkey   
                        AND   STC.ConfigKey = 'GVTEPODAPT1'  
                        AND   STC.SValue    = '1' )  
            BEGIN  
               IF @dt_TrackDate01 <> NULL
               BEGIN
                  SET @c_TrackDate01 = CONVERT(NVARCHAR(19),@dt_TrackDate01,120)

                  EXEC ispGenGVTLog 'GVTEPODAPT1', @c_OrderKey, @c_TrackDate01, @c_StorerKey, ''    
                                    , @b_success   OUTPUT    
                                    , @n_err       OUTPUT    
                                    , @c_errmsg    OUTPUT   
  
                  IF @b_success <> 1  
                  BEGIN  
                     SET @n_continue = 3  
                     GOTO QUIT   
                  END  
               END
            END 

            --GVTEPODAPT2
            IF EXISTS ( SELECT 1 FROM StorerConfig STC WITH (NOLOCK)     
                        WHERE STC.StorerKey = @c_Storerkey   
                        AND   STC.ConfigKey = 'GVTEPODAPT2'  
                        AND   STC.SValue    = '1' )  
            BEGIN  
               IF @dt_TrackDate02 <> NULL
               BEGIN
                  SET @c_TrackDate02 = CONVERT(NVARCHAR(19),@dt_TrackDate02,120)

                  EXEC ispGenGVTLog 'GVTEPODAPT2', @c_OrderKey, @c_TrackDate02, @c_StorerKey, ''    
                                    , @b_success   OUTPUT    
                                    , @n_err       OUTPUT    
                                    , @c_errmsg    OUTPUT   
  
                  IF @b_success <> 1  
                  BEGIN  
                     SET @n_continue = 3  
                     GOTO QUIT   
                  END  
               END
            END 

            --GVTEPODAPT3
            IF EXISTS ( SELECT 1 FROM StorerConfig STC WITH (NOLOCK)     
                        WHERE STC.StorerKey = @c_Storerkey   
                        AND   STC.ConfigKey = 'GVTEPODAPT3'  
                        AND   STC.SValue    = '1' )  
            BEGIN  
               IF @dt_TrackDate03 <> NULL
               BEGIN
                  SET @c_TrackDate03 = CONVERT(NVARCHAR(19),@dt_TrackDate03,120)

                  EXEC ispGenGVTLog 'GVTEPODAPT3', @c_OrderKey, @c_TrackDate03, @c_StorerKey, ''    
                                    , @b_success   OUTPUT    
                                    , @n_err       OUTPUT    
                                    , @c_errmsg    OUTPUT   
  
                  IF @b_success <> 1  
                  BEGIN  
                     SET @n_continue = 3  
                     GOTO QUIT   
                  END  
               END
            END 

            --GVTEPODAPT4
            IF EXISTS ( SELECT 1 FROM StorerConfig STC WITH (NOLOCK)     
                        WHERE STC.StorerKey = @c_Storerkey   
                        AND   STC.ConfigKey = 'GVTEPODAPT4'  
                        AND   STC.SValue    = '1' )  
            BEGIN  
               IF @dt_TrackDate04 <> NULL
               BEGIN
                  SET @c_TrackDate04 = CONVERT(NVARCHAR(19),@dt_TrackDate04,120)

                  EXEC ispGenGVTLog 'GVTEPODAPT4', @c_OrderKey, @c_TrackDate04, @c_StorerKey, ''    
                                    , @b_success   OUTPUT    
                                    , @n_err       OUTPUT    
                                    , @c_errmsg    OUTPUT   
  
                  IF @b_success <> 1  
                  BEGIN  
                     SET @n_continue = 3  
                     GOTO QUIT   
                  END  
               END
            END 

            --GVTEPODAPT5
            IF EXISTS ( SELECT 1 FROM StorerConfig STC WITH (NOLOCK)     
                        WHERE STC.StorerKey = @c_Storerkey   
                        AND   STC.ConfigKey = 'GVTEPODAPT5'  
                        AND   STC.SValue    = '1' )  
            BEGIN  
               IF @dt_TrackDate05 <> NULL
               BEGIN
                  SET @c_TrackDate05 = CONVERT(NVARCHAR(19),@dt_TrackDate05,120)

                  EXEC ispGenGVTLog 'GVTEPODAPT5', @c_OrderKey, @c_TrackDate05, @c_StorerKey, ''    
                                    , @b_success   OUTPUT    
                                    , @n_err       OUTPUT    
                                    , @c_errmsg    OUTPUT   
  
                  IF @b_success <> 1  
                  BEGIN  
                     SET @n_continue = 3  
                     GOTO QUIT   
                  END 
               END 
            END 
         END
      END
      /********************************************/    
      /* GVTITF (END)                             */    
      /********************************************/  
   END
   --(YT01)-E
/********************************************/  
/* Main Program (End)                       */  
/********************************************/  
  
/********************************************/  
/* Std - Error Handling (Start)             */  
/********************************************/  
QUIT:  
  
   WHILE @@TRANCOUNT < @n_StartTCnt  
      BEGIN TRAN  
  
   IF @n_Continue=3  -- Error Occured - Process And Return  
   BEGIN  
      SELECT @b_success = 0  
      IF @@TRANCOUNT > @n_StartTCnt  
      BEGIN  
         ROLLBACK TRAN  
      END  
      ELSE  
      BEGIN  
         WHILE @@TRANCOUNT > @n_StartTCnt  
         BEGIN  
            COMMIT TRAN  
         END  
      END  
      EXECUTE dbo.nsp_logerror @n_err, @c_errmsg, 'isp_ITF_ntrPOD'  
  
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR  
      RETURN  
   END  
   ELSE  
   BEGIN  
      SELECT @b_success = 1  
      WHILE @@TRANCOUNT > @n_StartTCnt  
      BEGIN  
         COMMIT TRAN  
      END  
      RETURN  
   END  
/********************************************/  
/* Std - Error Handling (End)               */  
/********************************************/  
END -- procedure  


GO