SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************************/    
/* Store Procedure:  isp_FinalizePendingCancel                                         */    
/* Creation Date: 12-May-2015                                                          */    
/* Copyright: LFL                                                                      */    
/* Written by:                                                                         */    
/*                                                                                     */    
/* Purpose: Presale Cancellation                                                       */    
/*                                                                                     */    
/* Input Parameters:  @c_DataStream    - Data Stream Code                              */    
/*                    @b_debug         - 0                                             */    
/*                                                                                     */    
/* Output Parameters: @b_Success       - Success Flag  = 0                             */    
/*                    @n_Err           - Error Code    = 0                             */    
/*                    @c_ErrMsg        - Error Message = ''                            */    
/*                                                                                     */    
/* Called By:                                                                          */    
/*                                                                                     */    
/* PVCS Version: 1.0                                                                   */    
/*                                                                                     */    
/* Version: 1.0                                                                        */    
/*                                                                                     */    
/* Data Modifications:                                                                 */    
/*                                                                                     */    
/* Updates:                                                                            */    
/* Date        Author   Ver.  Purposes                                                 */    
/* 14-Nov-2018 Leong    1.1   INC0469581 - Revise Svalue Logic.                        */    
/* 23-May-2019 kelvinongcy01 1.2 Revise Svalue logic @c_SC_WSSKIPCANC_SValue , add '1' */    
/* 17-Jun-2019 kelvinongcy02 1.3  Highlighted @n_Err = 80005, @c_SC_WSSKIPCANC_SValue  */   
/* 13-Nov-2019 Wan01    1.4  Fixed not Sum PickDetail.qty for movement                 */    
/****************************************************************************************/    
    
CREATE PROC [dbo].[isp_FinalizePendingCancel] (    
       @c_Orderkey         NVARCHAR(10)    
     , @b_debug            INT            = 0    
     , @b_Success          INT            = 0   OUTPUT    
     , @n_Err              INT            = 0   OUTPUT    
     , @c_ErrMsg           NVARCHAR(215)  = ''  OUTPUT    
) AS    
BEGIN    
   SET NOCOUNT ON    
   SET ANSI_NULLS OFF    
   SET ANSI_WARNINGS OFF    
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
    
   /*********************************************/    
   /* Variables Declaration (Start)             */    
   /*********************************************/    
   --General    
   DECLARE @n_Continue                 INT    
         , @n_StartTCnt                INT    
         , @c_ExecStatements           NVARCHAR(4000)    
         , @c_ExecArguments            NVARCHAR(4000)    
         , @c_Status0                  NVARCHAR(1)    
         , @c_Status1                  NVARCHAR(1)    
         , @c_Status9                  NVARCHAR(1)    
         , @c_BatchNo                  NVARCHAR(50)    
         , @c_Attachment1              NVARCHAR(125)    
         , @n_LogAttachmentID          INT    
         , @n_LogFilekey               INT    
         , @c_FilePrefix               NVARCHAR(30)    
         , @c_FileSurfix               NVARCHAR(4)    
         , @c_LogFileSurfix            NVARCHAR(4)    
         , @n_Exists                   INT    
         , @c_InvalidFlag              NVARCHAR(1)    
         , @c_InstOutLog               NVARCHAR(1)    
         , @dt_Getdate                 DATETIME    
         , @c_Getdate                  NVARCHAR(30)    
         , @c_LogFileName              NVARCHAR(60)    
         , @c_FileName                 NVARCHAR(60)    
         , @c_Subject                  NVARCHAR(256)    
         , @c_SendCancelSuccess        NVARCHAR(1)    
         , @n_Success_LogAttachmentID  INT    
         , @n_Success_LogFilekey       INT    
         , @c_Success_LogFileName    NVARCHAR(60)    
         , @c_SC_ByPassDelPreAlloc     NVARCHAR(30)    
         , @c_SC_SValue                NVARCHAR(10)    
         , @c_PreAllocatePickDetailKey NVARCHAR(10)    
         , @c_SC_WSOrdCancMoveToLoc    NVARCHAR(30)    
         , @c_SC_SValue1               NVARCHAR(10)    
         , @c_CL_ListName              NVARCHAR(10)    
         , @c_CL_Code                  NVARCHAR(30)    
         , @c_DefinedSOStatus          NVARCHAR(10)    
         , @n_WSOrdCancMoveToLoc_Exist INT    
         , @c_SC_WSSkipRemoveTrackNo   NVARCHAR(30)    
         , @c_SC_SValue2               NVARCHAR(10)    
         , @c_WSOrdCancMovePicked      NVARCHAR(30)    
         , @c_SC_SValue3               NVARCHAR(10)    
         , @n_SeqNo                    INT    
         , @c_TargetDBSchema           NVARCHAR(20)    
         , @n_AllowCancelCombineOrd    INT    
         , @c_ColumnName1              NVARCHAR(100)    
         , @c_ColumnValue1             NVARCHAR(100)    
         , @c_ExecStatements1          NVARCHAR(200)    
         , @n_WSOrdCancMoveToLoc_Task_Exist  INT    
         , @n_WSOrdCancMoveToLoc_PS_Exist    INT    
         , @c_SC_SValue4               NVARCHAR(10)    
         , @n_Cnt                      INT    
         , @c_StorerKey                NVARCHAR(15)    
         , @c_Facility                 NVARCHAR(5) = ''    
    
   --ITFLog    
   DECLARE @n_ITFLogkey                INT    
         , @dt_LogDateStart            DATETIME    
         , @dt_LogDateEnd              DATETIME    
         , @c_ITFType                  NVARCHAR(1)    
         , @n_NoOfRecCount             INT    
         , @n_ITFLogAttachmentID       INT    
         , @n_ITFErr                   INT    
         , @c_ITFStatus                NVARCHAR(10)    
         , @c_ITFErrMsg                NVARCHAR(215)    
    
   --Orders, WSDT_GENERIC_ORD_HDR    
   DECLARE @n_RecordId                 INT    
         , @c_InterfaceActionFlag      NVARCHAR(1)    
         , @c_ExternOrderKey           NVARCHAR(20)    
         , @c_WSDTStatus0              NVARCHAR(10)    
         , @c_WSDTStatus1              NVARCHAR(10)    
         , @c_WSDTStatus5              NVARCHAR(10)    
         , @c_WSDTStatus9              NVARCHAR(10)    
         , @c_StatusCANC               NVARCHAR(10)    
         , @c_StatusPENDCANC           NVARCHAR(10)    
         , @c_OrderStatus              NVARCHAR(10)    
         , @c_SOStatus                 NVARCHAR(10)    
         , @c_UpdOrdDetField           NVARCHAR(100)    
    
   --ORDERS, CartonTrack, PickingInfo, PackInfo, PackDetail    
   DECLARE @c_PickSlipNo               NVARCHAR(10)    
         , @n_CartonNo                 INT    
         , @c_LabelNo                  NVARCHAR(20)    
         , @c_LabelLine                NVARCHAR(5)    
         , @c_PickDetailKey            NVARCHAR(18)    
         , @c_PickHeaderKey            NVARCHAR(18)    
         , @c_LoadKey                  NVARCHAR(10)    
         , @c_LoadLineNumber           NVARCHAR(5)    
         , @c_OH_Orderkey              NVARCHAR(20)    
         , @c_OH_Status                NVARCHAR(10)    
         , @c_OH_SOStatus              NVARCHAR(10)    
         , @dt_OH_AddDate              DATETIME    
         , @c_OH_ShipperKey            NVARCHAR(15)    
         , @n_RowRef                   INT    
         , @c_OH_Facility              NVARCHAR(5)    
         , @c_Move2Loc_ListName        NVARCHAR(10)    
         , @c_OD_OrderLineNumber       NVARCHAR(5)    
         , @c_PD_SKU                   NVARCHAR(20)    
         , @c_SL_Loc                   NVARCHAR(10)    
         , @c_PD_Lot                   NVARCHAR(10)    
         , @c_PD_Loc                   NVARCHAR(10)    
         , @c_PD_ID                    NVARCHAR(18)    
         , @c_PD_Status                NVARCHAR(10)    
         , @c_PD_PickSlipNo            NVARCHAR(10)    
         , @c_SL_LocationType          NVARCHAR(10)    
         , @c_Loc_LocationType         NVARCHAR(10)    
 , @c_Move2Loc_Long            NVARCHAR(250)    
         , @c_Move2Loc_Short           NVARCHAR(10)    
         , @n_PD_Qty                   INT    
         , @c_Temp_OrderLineNumber     NVARCHAR(5)    
         , @c_Temp_Sku                 NVARCHAR(20)    
         , @c_Temp_Lot                 NVARCHAR(10)    
         , @c_Temp_FromLoc             NVARCHAR(10)    
         , @c_Temp_FromID             NVARCHAR(18)    
         , @c_Temp_ToLoc               NVARCHAR(10)    
         , @c_Temp_ToID                NVARCHAR(18)    
         , @n_Temp_Qty                 INT    
         , @dt_Temp_Datetime           DATETIME    
         , @c_From_Loc                 NVARCHAR(10)    
         , @c_From_ID                  NVARCHAR(18)    
         , @c_To_Loc                   NVARCHAR(10)    
         , @c_To_ID                    NVARCHAR(18)    
         , @c_CT_TrackingNo            NVARCHAR(20)    
         , @c_CT_EditWho               NVARCHAR(18)    
         , @c_CT_EditDate              NVARCHAR(30)    
         , @c_OrderGroup               NVARCHAR(20)    
         , @c_Reserved                 NVARCHAR(10)    
         , @c_OH_OrderGroup            NVARCHAR(20)    
         , @c_ConsoOrderKey            NVARCHAR(30)    
         , @c_ConsoOrd_OrdSts          NVARCHAR(10)    
         , @c_ConsoOrd_SOSts           NVARCHAR(10)    
         , @dt_ConsoOrd_AddDate        DATETIME    
         , @c_ChildOrderKey            NVARCHAR(10)    
         , @c_Prev_ChildOrderKey       NVARCHAR(10)    
         , @c_DB_ChildOrderKey         NVARCHAR(10)    
         , @c_DB_ChildOrderLineNumber  NVARCHAR(5)    
         , @c_OH_Doctype               NVARCHAR(1)    
         , @c_OH_Priority              NVARCHAR(10)    
         , @c_OH_ECOM_PRESALE_FLAG     NVARCHAR(2)    
         , @c_SC_WSFORCECANCORD        NVARCHAR(30)    
         , @c_SC_WSFORCECANCORD_SValue NVARCHAR(30)    
         , @c_SC_Option1               NVARCHAR(50)    
         , @c_SC_Option2               NVARCHAR(50)    
         , @c_MH_Userdefine10          NVARCHAR(50)    
         , @n_Exists_PRESALE           INT    
         , @c_SC_WSSKIPCANC            NVARCHAR(30)    
         , @c_SC_WSSKIPCANC_SValue     NVARCHAR(30)    
         , @c_SC_WSSKIPCANC_OPTION1    NVARCHAR(100)    
    
   -- Initialisation    
   SELECT @n_StartTCnt = @@TRANCOUNT, @n_Continue = 1, @b_Success = 0, @n_Err = 0, @c_ErrMsg = ''    
   SET @c_ExecStatements            = ''    
   SET @c_ExecArguments             = ''    
   SET @c_Status0                   = '0'    
   SET @c_Status1                   = '1'    
   SET @c_Status9                   = '9'    
   SET @c_BatchNo                   = ''    
   SET @c_Attachment1               = ''    
   SET @n_LogAttachmentID           = 0    
   SET @n_LogFilekey                = 0    
   SET @c_FilePrefix                = 'WSWMSORD_'    
   SET @c_FileSurfix                = '.txt'    
   SET @c_LogFileSurfix             = '.log'    
   SET @n_Exists                    = 0    
   SET @c_InvalidFlag               = 'N'    
   SET @c_InstOutLog                = 'N'    
   SET @dt_Getdate                  = GETDATE()    
   SET @c_Getdate                   = CONVERT(NVARCHAR(8), @dt_GetDate, 112) +    
                                      REPLACE(CONVERT(NVARCHAR(8), @dt_GetDate, 108), ':', '')    
   SET @c_LogFileName               = ''    
   SET @c_FileName                  = ''    
   SET @c_Subject                   = ''    
   SET @c_SendCancelSuccess         = ''    
   SET @n_Success_LogAttachmentID   = 0    
   SET @n_Success_LogFilekey        = 0    
   SET @c_Success_LogFileName       = ''    
   SET @c_SC_ByPassDelPreAlloc      = 'ByPassDeletePreAllocate'    
   SET @c_SC_SValue                 = ''    
   SET @c_PreAllocatePickDetailKey  = ''    
   SET @c_SC_WSOrdCancMoveToLoc     = 'WSOrdCancMoveToLoc'    
   SET @c_SC_SValue1                = ''    
   SET @c_CL_ListName               = 'ORDCANMAP'    
   SET @c_CL_Code                   = '5'    
   SET @c_DefinedSOStatus     = ''    
   SET @n_WSOrdCancMoveToLoc_Exist  = 0    
   SET @c_SC_WSSkipRemoveTrackNo    = 'WSSkipRemoveTrackNo'    
   SET @c_SC_SValue2                = ''    
   SET @c_WSOrdCancMovePicked       = 'WSOrdCancMovePicked'    
   SET @c_SC_SValue3                = ''    
   SET @n_SeqNo                     = 0    
   SET @c_TargetDBSchema            = ''    
   SET @n_AllowCancelCombineOrd     = 0    
   SET @c_ColumnName1               = ''    
   SET @c_ColumnValue1              = ''    
   SET @c_ExecStatements1           = ''    
    
   --Initialisation For ITFLog    
   SET @n_ITFLogkey                 = 0    
   SET @dt_LogDateStart             = GETDATE()    
   SET @c_ITFType                   = 'W'    
   SET @n_NoOfRecCount              = 0    
   SET @n_ITFLogAttachmentID        = 0    
   SET @n_ITFErr                    = 0    
   SET @c_ITFErrMsg                 = ''    
   SET @c_ITFStatus                 = ''    
    
   --Initialisation For Orders, WSDT_GENERIC_ORD_HDR    
   SET @n_RecordId                  = 0    
   SET @c_InterfaceActionFlag       = 'D'    
   SET @c_ExternOrderKey            = ''    
   SET @c_WSDTStatus0               = '0'    
   SET @c_WSDTStatus1               = '1'    
   SET @c_WSDTStatus5               = '5'    
   SET @c_WSDTStatus9               = '9'    
   SET @c_StatusCANC                = 'CANC'    
   SET @c_StatusPENDCANC            = 'PENDCANC'    
   SET @c_OrderStatus               = ''    
   SET @c_SOStatus                  = ''    
   SET @c_UpdOrdDetField            = ''    
    
   --Initialisation For ORDERS, CartonTrack, PickingInfo, PackInfo, PackDetail    
   SET @c_PickSlipNo                = ''    
   SET @n_CartonNo                  = 0    
   SET @c_LabelNo                   = ''    
   SET @c_LabelLine                 = ''    
   SET @c_PickDetailKey             = ''    
   SET @c_PickHeaderKey             = ''    
   SET @c_LoadKey                   = ''    
   SET @c_LoadLineNumber            = ''    
   SET @c_OH_Orderkey               = ''    
   SET @c_OH_Status                 = ''    
   SET @c_OH_SOStatus               = ''    
   SET @c_OH_ShipperKey             = ''    
   SET @n_RowRef                    = 0    
   SET @c_OH_Facility               = ''    
   SET @c_Move2Loc_ListName         = 'WSMove2Loc'    
   SET @c_OD_OrderLineNumber        = ''    
   SET @c_PD_SKU                    = ''    
   SET @c_SL_Loc                    = ''    
   SET @c_PD_Lot                    = ''    
   SET @c_PD_Loc                    = ''    
   SET @c_SL_LocationType           = ''    
   SET @c_Loc_LocationType          = ''    
   SET @c_Move2Loc_Long             = ''    
   SET @c_Move2Loc_Short            = ''    
   SET @n_PD_Qty                    = 0    
   SET @c_Temp_OrderLineNumber      = ''    
   SET @c_Temp_Sku                  = ''    
   SET @c_Temp_Lot                  = ''    
   SET @c_Temp_FromLoc              = ''    
   SET @c_Temp_FromID               = ''    
   SET @c_Temp_ToLoc                = ''    
   SET @c_Temp_ToID                 = ''    
   SET @n_Temp_Qty                  = 0    
   SET @c_From_Loc                  = ''    
   SET @c_From_ID                   = ''    
   SET @c_To_Loc                    = ''    
   SET @c_To_ID                     = ''    
   SET @c_CT_TrackingNo             = ''    
   SET @c_CT_EditWho                = ''    
   SET @c_CT_EditDate               = ''    
   SET @c_OrderGroup                = ''    
   SET @c_Reserved                  = ''    
   SET @c_OH_OrderGroup             = ''    
   SET @c_ConsoOrderKey             = ''    
   SET @c_ConsoOrd_OrdSts           = ''    
   SET @c_ConsoOrd_SOSts            = ''    
   SET @dt_ConsoOrd_AddDate         = NULL    
   SET @c_ChildOrderKey             = ''    
   SET @c_Prev_ChildOrderKey        = ''    
   SET @c_DB_ChildOrderKey          = ''    
   SET @c_DB_ChildOrderLineNumber   = ''    
   SET @c_OH_Doctype                = ''    
   SET @c_OH_Priority               = ''    
   SET @c_OH_ECOM_PRESALE_FLAG      = ''    
   
   SET @c_SC_WSFORCECANCORD         = 'WSFORCECANCORD'    
   SET @c_SC_WSFORCECANCORD_SValue  = ''    
   SET @c_SC_Option1                = ''    
   SET @c_SC_Option2                = ''    
   SET @c_MH_Userdefine10           = ''    
   SET @n_Exists_PRESALE            = 0    
    
   SET @c_SC_WSSKIPCANC             = 'WSSkipCancProcess'    
   SET @c_SC_WSSKIPCANC_SValue      = ''    
   SET @c_SC_WSSKIPCANC_OPTION1     = ''    
    
   IF OBJECT_ID('tempdb..#TempMoveRecord') IS NOT NULL    
   BEGIN    
      DROP TABLE #TempMoveRecord    
   END    
    
   CREATE TABLE #TempMoveRecord    
   (    
      OrderLineNumber NVARCHAR(5) NOT NULL,    
      SKU NVARCHAR(20) NULL,    
      Lot NVARCHAR(10) NULL,    
      FromLoc NVARCHAR(10) NULL,    
      FromID NVARCHAR(18) NULL,    
      ToLoc NVARCHAR(10) NULL,    
      ToID NVARCHAR(18) NULL,    
      Qty INT    
   )    
    
   --Get The Latest Order Info    
   SET @n_Exists = 0    
   SET @c_OH_Status = ''    
   SET @c_OH_SOStatus = ''    
   SET @c_OH_ShipperKey = ''    
   SET @c_OH_Facility = ''    
    
   SET @c_InstOutLog = 'N'    
   SET @c_ExternOrderKey = ''    
   SET @c_OrderGroup = ''    
   SET @c_Reserved = ''    
   SET @c_UpdOrdDetField = ''    
    
   SELECT  @n_Exists = (1)    
         , @c_OH_Status = ISNULL(RTRIM(STATUS),'')    
         , @c_OH_SOStatus = ISNULL(RTRIM(SOStatus),'')    
         , @c_OH_ShipperKey = ISNULL(RTRIM(ShipperKey),'')    
         , @c_OH_Facility = ISNULL(RTRIM(Facility),'')    
         , @c_ExternOrderKey = ISNULL(RTRIM(ExternOrderKey), '')    
         , @c_OrderGroup = ISNULL(RTRIM(OrderGroup), '')    
         , @c_StorerKey = StorerKey    
   FROM ORDERS WITH (NOLOCK)    
   WHERE OrderKey = @c_OrderKey    
    
   SET @c_DefinedSOStatus = ''    
    
   SELECT @c_DefinedSOStatus = ISNULL(RTRIM(Short), '')    
   FROM dbo.CODELKUP WITH (NOLOCK)    
   WHERE ListName = 'ORDCANMAP'    
   AND Code = '5'    
   AND StorerKey = @c_StorerKey    
    
   SELECT @c_SC_SValue = SValue    
    FROM StorerConfig WITH (NOLOCK)    
    WHERE StorerKey = @c_Storerkey    
    AND ConfigKey = 'ByPassDeletePreAllocate'    
    
   SELECT @n_WSOrdCancMoveToLoc_Exist = (1)    
    FROM StorerConfig WITH (NOLOCK)    
    WHERE StorerKey = @c_Storerkey    
    AND ConfigKey = 'WSOrdCancMoveToLoc'    
    
   SELECT @n_WSOrdCancMoveToLoc_Task_Exist = (1)    
   FROM StorerConfig WITH (NOLOCK)    
   WHERE StorerKey = @c_Storerkey    
   AND ConfigKey = 'WSOrdCancMV2Loc_Task'    
   AND SValue = '1'    
    
   SELECT @n_WSOrdCancMoveToLoc_PS_Exist = (1)    
   FROM StorerConfig WITH (NOLOCK)    
   WHERE StorerKey = @c_Storerkey    
   AND ConfigKey = 'WSOrdCancMV2Loc_PickStatus'    
   AND SValue = '1'    
    
   SELECT @c_SC_SValue2 = SValue    
   FROM StorerConfig WITH (NOLOCK)    
   WHERE StorerKey = @c_Storerkey    
   AND ConfigKey = 'WSSkipRemoveTrackNo'    
    
   SELECT @c_SC_WSFORCECANCORD_SValue = SValue    
   , @c_SC_Option1 = ISNULL(RTRIM(OPTION1), '')    
   , @c_SC_Option2 = ISNULL(RTRIM(OPTION2), '')    
   FROM StorerConfig WITH (NOLOCK)    
   WHERE StorerKey = @c_Storerkey    
   AND ConfigKey = 'WSFORCECANCORD'    
    
   SELECT    
      @c_SC_WSSKIPCANC_SValue = SValue    
    , @c_SC_WSSKIPCANC_Option1 = ISNULL(RTRIM(OPTION1), '')    
   FROM StorerConfig WITH (NOLOCK)    
   WHERE StorerKey = @c_Storerkey    
   AND ConfigKey = 'WSSkipCancProcess'    
    
   IF EXISTS(SELECT 1 FROM #TempMoveRecord WITH (NOLOCK))    
   BEGIN    
      TRUNCATE TABLE #TempMoveRecord    
   END    
    
    
    
   IF @c_OrderGroup = 'CHILD_ORD'    
   BEGIN    
      SET @c_ChildOrderKey = @c_OrderKey    
   END    
    
   IF @n_Exists = 0    
   BEGIN    
      SET @c_InvalidFlag = 'Y'    
      SET @c_InstOutLog = 'Y'    
      SET @n_Err = 80004    
      SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), ISNULL(@n_Err, 0)) +    
                        ': OrderKey = ' + @c_OrderKey + ', StorerKey = ' + @c_Storerkey +    
                        ' Does Not Exists. (isp_FinalizePendingCancel)'    
      GOTO PROCESS_UPDATE    
 END    
    
   IF ISNUMERIC(@c_OH_Status) = 0    
   BEGIN    
      SET @c_InvalidFlag = 'Y'    
      SET @c_InstOutLog = 'Y'    
      SET @n_Err = 80005    
      SET @c_ErrMsg = 'StorerKey = ' + @c_Storerkey + ', OrderKey = ' + @c_OrderKey +    
                        ', Order Cannot Be Cancelled, Status = ''' + @c_OH_Status +    
                        '''. (isp_FinalizePendingCancel)'    
      GOTO PROCESS_UPDATE    
   END    
    
   --IF ISNULL(RTRIM(@c_SC_WSSKIPCANC_SValue),'') NOT IN ('','0') -- @c_SC_WSSKIPCANC_SValue <> '1' -- INC0469581    
   --IF ISNULL(RTRIM(@c_SC_WSSKIPCANC_SValue),'') NOT IN ('1','','0')  -- kelvinongcy01, kelvinongcy02    
   --BEGIN    
   --   SET @n_Err = 80005    
   --   SET @c_ErrMsg = 'StorerKey = ' + @c_Storerkey + ', OrderKey = ' + @c_OrderKey +    
   --               ', Order Cannot Be Cancelled, WSSkipCancProcess is Not Setup ' +    
   --               '. (isp_FinalizePendingCancel)'    
   --   GOTO PROCESS_UPDATE    
   --END    
    
   IF @c_OH_Status > '5'    
   BEGIN    
      SET @c_InvalidFlag = 'Y'    
      SET @c_InstOutLog = 'Y'    
      SET @n_Err = 80006    
      SET @c_ErrMsg = 'StorerKey = ' + @c_Storerkey + ', OrderKey = ' + @c_OrderKey +    
                     ', Order Cannot Be Cancelled, Status = ''' + @c_OH_Status +    
                     '''. (isp_FinalizePendingCancel)'    
      GOTO PROCESS_UPDATE    
   END    
    
   /*********************************************/    
   /* Generate Temp Move Record (Start)         */    
   /*********************************************/    
   IF @n_WSOrdCancMoveToLoc_Exist = 1 OR @n_WSOrdCancMoveToLoc_Task_Exist = 1    
      OR @n_WSOrdCancMoveToLoc_PS_Exist = 1    
   BEGIN    
      /*********************************************/    
      /* Get StorerConfig (Start)                 */    
      /*********************************************/    
      SET @c_SC_SValue1 = ''    
      SELECT @c_SC_SValue1 = SValue    
      FROM StorerConfig WITH (NOLOCK)    
      WHERE StorerKey = @c_Storerkey    
      AND ConfigKey = 'WSOrdCancMoveToLoc'    
      AND Facility = @c_OH_Facility    
    
      SET @c_SC_SValue3 = ''    
      SELECT @c_SC_SValue3 = SValue    
      FROM StorerConfig WITH (NOLOCK)    
      WHERE StorerKey = @c_Storerkey    
      AND ConfigKey = 'WSOrdCancMovePicked'    
      AND Facility = @c_OH_Facility    
    
      IF @n_WSOrdCancMoveToLoc_Task_Exist = 1 AND @n_WSOrdCancMoveToLoc_PS_Exist = 1    
      BEGIN    
         SET @c_SC_SValue1 = ''    
      END    
      ELSE    
      BEGIN    
         IF @n_WSOrdCancMoveToLoc_Task_Exist = 1    
         BEGIN    
            SET @n_Cnt = 0    
            SELECT @n_Cnt = Count(1)    
            FROM PickDetail WITH (NOLOCK)    
            WHERE Orderkey = @c_Orderkey    
            AND  (PickSlipNo IS NOT NULL AND PickSlipNo <> '')    
    
            IF @n_Cnt = 0    
            BEGIN    
               SET @c_SC_SValue1 = ''    
            END    
         END    
    
         IF @n_WSOrdCancMoveToLoc_PS_Exist = 1    
         BEGIN    
            SET @n_Cnt = 0    
    
            SELECT @n_Cnt = Count(1)    
            FROM PickDetail WITH (NOLOCK)    
            WHERE Orderkey = @c_Orderkey    
            AND   (Status = '3' OR Status = '5')    
    
            IF @n_Cnt = 0    
            BEGIN    
               SET @c_SC_SValue1 = ''    
            END    
         END    
      END -- @n_WSOrdCancMoveToLoc_Task_Exist = 1 AND @n_WSOrdCancMoveToLoc_PS_Exist = 1    
    
      IF @b_Debug = 1    
      BEGIN    
         PRINT '[isp_FinalizePendingCancel]: @c_SC_SValue1 = ' + @c_SC_SValue1    
               + ',  @c_SC_SValue3 = ' + @c_SC_SValue3    
               + ',  @c_SC_SValue4 = ' + @c_SC_SValue4    
      END    
      /*********************************************/    
      /* Get StorerConfig (End)                   */    
      /*********************************************/    
      /* Insert Temp Table (Start)                */    
      /*********************************************/    
      IF @c_SC_SValue1 <> ''    
      BEGIN    
         IF @b_Debug = 1    
         BEGIN    
            PRINT '[isp_FinalizePendingCancel]: Start Insert Temp Table...'    
         END    
    
         DECLARE C_TempInsert CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
            SELECT ISNULL(RTRIM(OD.OrderLineNumber), '')  --DISTINCT ISNULL(RTRIM(OD.OrderLineNumber), '')  --(Wan01)  
            , ISNULL(RTRIM(PD.SKU), '')    
            , ISNULL(RTRIM(PD.Lot), '')    
            , ISNULL(RTRIM(PD.Loc), '')    
            , ISNULL(RTRIM(PD.ID), '')    
            , SUM(ISNULL(PD.Qty, 0))                                                                        --(Wan01)  
            , PD.[Status]    
            , PD.PickSlipNo    
            FROM ORDERDETAIL OD WITH (NOLOCK)    
            INNER JOIN PickDetail PD WITH (NOLOCK)    
            ON (OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber    
            AND OD.SKU = PD.SKU AND OD.StorerKey = PD.StorerKey)    
            WHERE OD.OrderKey = @c_OrderKey   
            --(Wan01) - START  
            GROUP BY  
              ISNULL(RTRIM(OD.OrderLineNumber), '')    
            , ISNULL(RTRIM(PD.SKU), '')    
            , ISNULL(RTRIM(PD.Lot), '')    
            , ISNULL(RTRIM(PD.Loc), '')    
            , ISNULL(RTRIM(PD.ID), '')   
            , PD.[Status]    
            , PD.PickSlipNo    
            --(Wan01) - END      
            ORDER BY ISNULL(RTRIM(OD.OrderLineNumber), '')    
    
         OPEN C_TempInsert    
         FETCH NEXT FROM C_TempInsert INTO @c_OD_OrderLineNumber ,@c_PD_SKU         ,@c_PD_Lot    
                                          ,@c_PD_Loc             ,@c_PD_ID          ,@n_PD_Qty    
                         ,@c_PD_Status          ,@c_PD_PickSlipNo    
    
         WHILE @@FETCH_STATUS <> -1    
         BEGIN    
            IF @c_SC_SValue3 = '1' AND  @c_PD_Status <> '5'    
               GOTO NEXT_PICKDETAIL_RECORD    
    
            IF @n_WSOrdCancMoveToLoc_PS_Exist = 1 AND @c_PD_Status NOT IN ('3','5')    
               GOTO NEXT_PICKDETAIL_RECORD    
    
            IF @n_WSOrdCancMoveToLoc_Task_Exist = 1 AND  ISNULL(RTRIM(@c_PD_PickSlipNo), '') = ''    
               GOTO NEXT_PICKDETAIL_RECORD    
    
            IF @b_Debug = 1    
            BEGIN    
               PRINT '[isp_FinalizePendingCancel]: @c_OD_OrderLineNumber = ' + @c_OD_OrderLineNumber    
                     + ', @c_PD_SKU=' + @c_PD_SKU + ', @c_PD_Lot=' + @c_PD_Lot + ', @c_PD_Loc=' + @c_PD_Loc    
                     + ', @n_PD_Qty=' + CAST(CAST(@n_PD_Qty AS INT)AS NVARCHAR) + ', @c_PD_ID=' + @c_PD_ID    
            END    
    
            SET @c_From_Loc = @c_PD_Loc    
            SET @c_From_ID = @c_PD_ID    
            SET @c_To_Loc = ''    
            SET @c_To_ID = ''    
    
            /*Follow the logic below    
            -----------------------------------------------    
            Location Type  | Virtual   | Pick   | Original    
            -----------------------------------------------    
            Pick           | N         | N      | N    
            -----------------------------------------------    
            Bulk           | Y         | Y      | N    
            -----------------------------------------------    
            */    
    
            --Check Sku From Pick Location Or Bulk Location    
            /*********************************************/    
            /* Get LocationType (Start)                 */    
            /*********************************************/    
            SET @c_SL_LocationType = ''    
            SELECT @c_SL_LocationType = ISNULL(RTRIM(LocationType), '')    
            FROM SKUxLOC WITH (NOLOCK)    
            WHERE SKU = @c_PD_SKU    
            AND StorerKey = @c_Storerkey    
            AND Loc = @c_PD_Loc    
    
            IF @b_Debug = 1    
            BEGIN    
               PRINT '[iisp_FinalizePendingCancel]: @c_SL_LocationType=' + @c_SL_LocationType    
            END    
            /*********************************************/    
            /* Get LocationType (End)                    */    
            /*********************************************/    
            /* Get LocationType (Start)                  */    
            /*********************************************/    
            SET @c_Loc_LocationType = ''    
            SELECT @c_Loc_LocationType = ISNULL(RTRIM(LocationType), '')    
            FROM LOC WITH (NOLOCK)    
            WHERE Loc = @c_PD_Loc    
    
            IF @b_Debug = 1    
            BEGIN    
               PRINT '[iisp_FinalizePendingCancel]: @c_Loc_LocationType=' + @c_Loc_LocationType    
            END    
            /*********************************************/    
            /* Get LocationType (End)                   */    
            /*********************************************/    
            /* Verify Based On Location Type (Start)    */    
            /*********************************************/    
            IF @c_SL_LocationType IN ('CASE', 'PICK')    
            BEGIN    
               GOTO NEXT_PICKDETAIL_RECORD    
            END    
            ELSE    
            BEGIN    
               IF @c_Loc_LocationType IN ('DYNPICKP', 'DYNPICKR')    
                  GOTO NEXT_PICKDETAIL_RECORD    
            END    
            /*********************************************/    
            /* Verify Based On Location Type (End)      */    
            /*********************************************/    
    
            IF @c_SC_SValue1 = 'PCK_LOC'    
            BEGIN    
               --Get Pick Location    
               SET @c_SL_Loc = ''    
    
               SELECT TOP 1    
                     @c_SL_Loc = ISNULL(RTRIM(SL.Loc), '')    
               FROM SKUxLOC SL WITH (NOLOCK)    
               INNER JOIN LOC Loc WITH (NOLOCK) ON (SL.Loc = Loc.Loc)    
               WHERE SL.Sku = @c_PD_SKU    
             AND SL.StorerKey = @c_Storerkey    
               AND SL.LocationType = 'PICK'    
               AND Loc.Facility = @c_OH_Facility    
    
               IF @b_Debug = 1    
               BEGIN    
                  PRINT '[isp_FinalizePendingCancel]: @c_SL_Loc = ' + @c_SL_Loc    
               END    
    
               IF @c_SL_Loc <> ''    
                  SET @c_To_Loc = @c_SL_Loc    
            END --IF @c_SC_SValue1 = 'PCK_LOC'    
    
            IF @c_SC_SValue1 = 'TMP_LOC'    
            BEGIN    
               IF @c_SL_LocationType = ''    
                  SET @c_SL_LocationType = @c_Loc_LocationType    
    
               /*********************************************/    
               /* Get Codelkup Location (Start)            */    
               /*********************************************/    
               SET @c_Move2Loc_Long = ''    
               SET @c_Move2Loc_Short = ''    
               SELECT @c_Move2Loc_Long = ISNULL(RTRIM(Long), '')    
                     , @c_Move2Loc_Short = ISNULL(RTRIM(Short), '')    
                  FROM CODELKUP WITH (NOLOCK)    
                  WHERE ListName = @c_Move2Loc_ListName    
                  AND Code = @c_OH_Facility    
                  AND Code2 = @c_SL_LocationType    
                  AND StorerKey = @c_Storerkey    
    
               IF @b_Debug = 1    
               BEGIN    
                  PRINT '[isp_FinalizePendingCancel]: @c_Move2Loc_Long=' + @c_Move2Loc_Long    
                  PRINT '[isp_FinalizePendingCancel]: @c_Move2Loc_Short=' + @c_Move2Loc_Short    
               END    
    
               IF @c_Move2Loc_Long <> ''    
                  SET @c_To_Loc = @c_Move2Loc_Long    
    
               IF @c_Move2Loc_Short <> ''    
                  SET @c_To_ID = @c_Move2Loc_Short    
               /*********************************************/    
               /* Get Codelkup Location (End)              */    
               /*********************************************/    
            END --IF @c_SC_SValue1 = 'TMP_LOC'    
    
            IF @c_To_Loc <> ''    
            BEGIN    
     INSERT INTO #TempMoveRecord (    
                  OrderLineNumber, SKU, Lot, FromLoc, FromID, ToLoc, ToID, Qty )    
               VALUES    
               ( @c_OD_OrderLineNumber, @c_PD_SKU, @c_PD_Lot, @c_From_Loc, @c_From_ID, @c_To_Loc, @c_To_ID, @n_PD_Qty )    
            END --IF @c_To_Loc <> ''    
    
    
            NEXT_PICKDETAIL_RECORD:    
    
            FETCH NEXT FROM C_TempInsert INTO @c_OD_OrderLineNumber ,@c_PD_SKU         ,@c_PD_Lot    
                                             ,@c_PD_Loc             ,@c_PD_ID          ,@n_PD_Qty    
                                             ,@c_PD_Status          ,@c_PD_PickSlipNo    
         END -- WHILE @@FETCH_STATUS <> -1    
         CLOSE C_TempInsert    
         DEALLOCATE C_TempInsert    
      END --IF @c_SC_SValue1 <> ''    
      /*********************************************/    
      /* Insert Temp Table (End)                  */    
      /*********************************************/    
   END --IF @n_WSOrdCancMoveToLoc_Exist = 1    
   /*********************************************/    
   /* Generate Temp Move Record (End)           */    
   /*********************************************/    
   /* Update Order Status (Start)               */    
   /*********************************************/    
   IF @c_OH_Status > '0'    
   BEGIN    
      -- Unallocate Orders    
      /*********************************************/    
      /* Delete Picking Info (Start)              */    
      /*********************************************/    
      SET @c_ExecStatements = ''    
      SET @c_ExecArguments  = ''    
      SET @c_PickSlipNo     = ''    
    
      IF CURSOR_STATUS('LOCAL' , 'C_PickingInfo_Delete') in (0 , 1)    
      BEGIN    
         CLOSE C_PickingInfo_Delete    
         DEALLOCATE C_PickingInfo_Delete    
      END    
    
      DECLARE C_PickingInfo_Delete CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
         SELECT PickHeaderKey    
         FROM PickHeader WITH (NOLOCK)    
         WHERE Orderkey = @c_Orderkey    
         ORDER BY PickHeaderKey    
    
      OPEN C_PickingInfo_Delete    
      FETCH NEXT FROM C_PickingInfo_Delete INTO @c_PickHeaderKey    
    
      WHILE @@FETCH_STATUS <> -1    
      BEGIN    
         DELETE PickingInfo    
         WHERE PickSlipNo = @c_PickHeaderKey    
    
         IF @@ERROR <> 0    
         BEGIN    
            SET @c_InvalidFlag = 'Y'    
            SET @c_InstOutLog = 'Y'    
            SET @n_Err = 68116    
            SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0))    
                           + ': Fail To Unallocate OrderKey = ' + @c_OrderKey    
                           + '. Delete PickingInfo Fail. (isp_FinalizePendingCancel)'    
            GOTO PROCESS_UPDATE    
         END    
    
         WHILE @@TRANCOUNT > 0    
            COMMIT TRAN    
    
         FETCH NEXT FROM C_PickingInfo_Delete INTO @c_PickHeaderKey    
      END -- WHILE @@FETCH_STATUS <> -1    
      CLOSE C_PickingInfo_Delete    
      DEALLOCATE C_PickingInfo_Delete    
      /*********************************************/    
      /* Delete Picking Info (End)                */    
      /*********************************************/    
      /* Delete Pick Detail (Start)               */    
      /*********************************************/    
      SET @c_ExecStatements = ''    
      SET @c_ExecArguments  = ''    
    
      IF CURSOR_STATUS('LOCAL' , 'C_PickDetail_Delete') in (0 , 1)    
      BEGIN    
         CLOSE C_PickDetail_Delete    
         DEALLOCATE C_PickDetail_Delete    
      END    
    
      DECLARE C_PickDetail_Delete CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
         SELECT PickDetailKey    
         FROM PickDetail WITH (NOLOCK)    
         WHERE Orderkey = @c_Orderkey    
         ORDER BY PickDetailKey    
    
      OPEN C_PickDetail_Delete    
      FETCH NEXT FROM C_PickDetail_Delete INTO @c_PickDetailKey    
    
      WHILE @@FETCH_STATUS <> -1    
      BEGIN    
         SET @c_ITFErrMsg = 'Start Delete PickDetailKey=' + @c_PickDetailKey    
         SET @c_ITFErrMsg = 'Start Delete PickDetail for PickDetailKey=' + @c_PickDetailKey    
    
         DELETE PickDetail    
         WHERE PickDetailKey = @c_PickDetailKey    
    
         IF @@ERROR <> 0    
         BEGIN    
            SET @c_InvalidFlag = 'Y'    
            SET @c_InstOutLog = 'Y'    
            SET @n_Err = 68117    
            SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0))    
                           + ': Fail To Unallocate OrderKey = ' + @c_OrderKey    
                           + '. Delete PickDetail Fail (isp_FinalizePendingCancel)'    
    
            GOTO PROCESS_UPDATE    
         END    
    
         WHILE @@TRANCOUNT > 0    
            COMMIT TRAN    
    
         FETCH NEXT FROM C_PickDetail_Delete INTO @c_PickDetailKey    
      END -- WHILE @@FETCH_STATUS <> -1    
      CLOSE C_PickDetail_Delete    
      DEALLOCATE C_PickDetail_Delete    
      /*********************************************/    
      /* Delete Pick Detail (End)                 */    
      /*********************************************/    
      /* Delete Pick Header (Start)               */    
      /*********************************************/    
      SET @c_ExecStatements = ''    
      SET @c_ExecArguments  = ''    
    
      IF CURSOR_STATUS('LOCAL' , 'C_PickHeader_Delete') in (0 , 1)    
      BEGIN    
         CLOSE C_PickHeader_Delete    
         DEALLOCATE C_PickHeader_Delete    
      END    
    
      DECLARE C_PickHeader_Delete CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
         SELECT PickHeaderKey    
         FROM PickHeader WITH (NOLOCK)    
         WHERE Orderkey = @c_Orderkey    
         ORDER BY PickHeaderKey    
    
      OPEN C_PickHeader_Delete    
      FETCH NEXT FROM C_PickHeader_Delete INTO @c_PickHeaderKey    
    
      WHILE @@FETCH_STATUS <> -1    
      BEGIN    
         DELETE PickHeader    
         WHERE PickHeaderKey = @c_PickHeaderKey    
    
         IF @@ERROR <> 0    
         BEGIN    
            SET @c_InvalidFlag = 'Y'    
            SET @c_InstOutLog = 'Y'    
            SET @n_Err = 68118    
            SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0))    
                           + ': Fail To Unallocate OrderKey = ' + @c_OrderKey    
                           + '. Delete PickHeader Fail. (isp_FinalizePendingCancel)'    
            GOTO PROCESS_UPDATE    
         END    
    
         WHILE @@TRANCOUNT > 0    
            COMMIT TRAN    
    
         FETCH NEXT FROM C_PickHeader_Delete INTO @c_PickHeaderKey    
      END -- WHILE @@FETCH_STATUS <> -1    
      CLOSE C_PickHeader_Delete    
      DEALLOCATE C_PickHeader_Delete    
      /*********************************************/    
      /* Delete Pick Header (End)                 */    
      /*********************************************/    
      /* Delete Pack Info (Start)                 */    
      /*********************************************/    
      SET @c_ExecStatements = ''    
      SET @c_ExecArguments  = ''    
      SET @c_PickSlipNo     = ''    
      SET @n_CartonNo       = 0    
    
      IF CURSOR_STATUS('LOCAL' , 'C_PackInfo_Delete') in (0 , 1)    
      BEGIN    
         CLOSE C_PackInfo_Delete    
         DEALLOCATE C_PackInfo_Delete    
      END    
    
      DECLARE C_PackInfo_Delete CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
         SELECT A.PickSlipNo , A.CartonNo    
         FROM PackInfo A WITH (NOLOCK)    
         INNER JOIN PackHeader B WITH (NOLOCK) ON A.PickSlipNo = B.PickSlipNo    
         WHERE B.OrderKey = @c_Orderkey    
         AND B.StorerKey = @c_StorerKey    
         ORDER BY A.PickSlipNo, A.CartonNo    
    
      OPEN C_PackInfo_Delete    
      FETCH NEXT FROM C_PackInfo_Delete INTO @c_PickSlipNo, @n_CartonNo    
    
      WHILE @@FETCH_STATUS <> -1    
      BEGIN    
         DELETE PackInfo    
         WHERE PickSlipNo = @c_PickSlipNo AND CartonNo = @n_CartonNo    
    
         IF @@ERROR <> 0    
         BEGIN    
            SET @c_InvalidFlag = 'Y'    
          SET @c_InstOutLog = 'Y'    
            SET @n_Err = 68119    
            SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0))    
                           + ': Fail To Unallocate OrderKey = ' + @c_OrderKey    
                           + '. Delete PackInfo Fail. (isp_FinalizePendingCancel)'    
            GOTO PROCESS_UPDATE    
         END    
    
         WHILE @@TRANCOUNT > 0    
            COMMIT TRAN    
    
         FETCH NEXT FROM C_PackInfo_Delete INTO @c_PickSlipNo, @n_CartonNo    
      END -- WHILE @@FETCH_STATUS <> -1    
      CLOSE C_PackInfo_Delete    
      DEALLOCATE C_PackInfo_Delete    
      /*********************************************/    
      /* Delete Pack Info (End)                   */    
      /*********************************************/    
      /* Delete Pack Header & Detail (Start)      */    
      /*********************************************/    
      SET @c_ExecStatements = ''    
      SET @c_ExecArguments  = ''    
      SET @c_PickSlipNo     = ''    
      SET @n_CartonNo       = 0    
      SET @c_LabelNo        = ''    
      SET @c_LabelLine      = ''    
    
      IF CURSOR_STATUS('LOCAL' , 'C_PackHeader_Delete') in (0 , 1)    
      BEGIN    
         CLOSE C_PackHeader_Delete    
         DEALLOCATE C_PackHeader_Delete    
      END    
    
      IF CURSOR_STATUS('LOCAL' , 'C_PackDetail_Delete') in (0 , 1)    
      BEGIN    
         CLOSE C_PackDetail_Delete    
         DEALLOCATE C_PackDetail_Delete    
      END    
    
      DECLARE C_PackHeader_Delete CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
         SELECT PickSlipNo    
         FROM PackHeader WITH (NOLOCK)    
         WHERE OrderKey = @c_Orderkey AND StorerKey = @c_StorerKey    
         ORDER BY PickSlipNo    
    
      OPEN C_PackHeader_Delete    
      FETCH NEXT FROM C_PackHeader_Delete INTO @c_PickSlipNo    
    
      WHILE @@FETCH_STATUS <> -1    
      BEGIN    
         /*********************************************/    
         /* Delete Pack Detail (Start)               */    
         /*********************************************/    
         DECLARE C_PackDetail_Delete CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
            SELECT CartonNo, LabelNo, LabelLine    
            FROM PackDetail WITH (NOLOCK)    
            WHERE PickSlipNo = @c_PickSlipNo    
            ORDER BY CartonNo    
    
         OPEN C_PackDetail_Delete    
         FETCH NEXT FROM C_PackDetail_Delete INTO @n_CartonNo, @c_LabelNo, @c_LabelLine    
    
         WHILE @@FETCH_STATUS <> -1    
       BEGIN    
            DELETE PackDetail    
            WHERE PickSlipNo = @c_PickSlipNo    
            AND CartonNo = @n_CartonNo    
            AND LabelNo = @c_LabelNo    
            AND LabelLine = @c_LabelLine    
    
            IF @@ERROR <> 0    
            BEGIN    
               SET @c_InvalidFlag = 'Y'    
               SET @c_InstOutLog = 'Y'    
               SET @n_Err = 68120    
               SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0))    
                              + ': Fail To Unallocate OrderKey = ' + @c_OrderKey    
                              + '. Delete PackDetail Fail. (isp_FinalizePendingCancel)'    
               GOTO PROCESS_UPDATE    
            END    
    
            WHILE @@TRANCOUNT > 0    
               COMMIT TRAN    
    
            FETCH NEXT FROM C_PackDetail_Delete INTO @n_CartonNo, @c_LabelNo, @c_LabelLine    
         END -- WHILE @@FETCH_STATUS <> -1    
         CLOSE C_PackDetail_Delete    
         DEALLOCATE C_PackDetail_Delete    
         /*********************************************/    
         /* Delete Pack Detail (End)                 */    
         /*********************************************/    
         /* Delete Pack Header (Start)               */    
         /*********************************************/    
         DELETE PackHeader    
         WHERE PickSlipNo = @c_PickSlipNo    
    
         IF @@ERROR <> 0    
         BEGIN    
            SET @c_InvalidFlag = 'Y'    
SET @c_InstOutLog = 'Y'    
            SET @n_Err = 68121    
            SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0))    
                           + ': Fail To Unallocate OrderKey = ' + @c_OrderKey    
                           + '. Delete PackHeader Fail. (isp_FinalizePendingCancel)'    
            GOTO PROCESS_UPDATE    
         END    
    
         WHILE @@TRANCOUNT > 0    
            COMMIT TRAN    
         /*********************************************/    
         /* Delete Pack Header (End)                 */    
         /*********************************************/    
    
         FETCH NEXT FROM C_PackHeader_Delete INTO @c_PickSlipNo    
      END -- WHILE @@FETCH_STATUS <> -1    
      CLOSE C_PackHeader_Delete    
      DEALLOCATE C_PackHeader_Delete    
      /*********************************************/    
      /* Delete Pack Header & Detail (End)        */    
      /*********************************************/    
      /* Update Order Status = 0 (Start)          */    
      /*********************************************/    
      SET @c_ExecStatements= ''    
      SET @c_OrderStatus = '0'    
    
      UPDATE ORDERS WITH (ROWLOCK)    
         SET EditWho = SUSER_NAME()    
         , EditDate = GETDATE()    
         , Trafficcop = NULL    
         , Status = @c_OrderStatus    
         WHERE Orderkey = @c_Orderkey    
    
      IF @@ERROR <> 0    
      BEGIN    
         SET @c_InvalidFlag = 'Y'    
         SET @c_InstOutLog = 'Y'    
         SET @n_Err = 80013    
         SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0))    
                        + ': Update Order Status Fail for ExternOrderKey' + @c_ExternOrderKey    
                        + '. (isp_FinalizePendingCancel)'    
         GOTO PROCESS_UPDATE    
      END    
    
      WHILE @@TRANCOUNT > 0    
         COMMIT TRAN    
      /*********************************************/    
      /* Update Order Status = 0 (End)            */    
      /*********************************************/    
      /*********************************************/    
      /* Generate Move Back To Inventory (Start)  */    
      /*********************************************/    
      IF EXISTS(SELECT 1 FROM #TempMoveRecord WITH (NOLOCK))    
      BEGIN    
         IF @b_Debug = 1    
         BEGIN    
            PRINT '[isp1586P_WSIML_CN_Skechers_CancOrd_Import]: Start Generate Move Back To Inventory...'    
         END    
    
         IF CURSOR_STATUS('LOCAL' , 'C_TempMoveRecord_Loop') in (0 , 1)    
         BEGIN    
            CLOSE C_TempMoveRecord_Loop    
            DEALLOCATE C_TempMoveRecord_Loop    
         END    
    
         DECLARE C_TempMoveRecord_Loop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
         SELECT DISTINCT OrderLineNumber    
         FROM #TempMoveRecord WITH (NOLOCK)    
         ORDER BY OrderLineNumber    
         OPEN C_TempMoveRecord_Loop    
         FETCH NEXT FROM C_TempMoveRecord_Loop INTO @c_Temp_OrderLineNumber    
         WHILE @@FETCH_STATUS <> -1    
         BEGIN    
            IF @b_Debug = 1    
            BEGIN    
               PRINT '[isp1586P_WSIML_CN_Skechers_CancOrd_Import]: Process @c_Temp_OrderLineNumber=' + @c_Temp_OrderLineNumber    
            END    
    
            SET @c_Temp_Sku = ''    
            SET @c_Temp_Lot = ''    
            SET @c_Temp_ToLoc = ''    
            SET @n_Temp_Qty = 0    
            SET @dt_Temp_Datetime = GETDATE()    
    
            SELECT @c_Temp_Sku = ISNULL(RTRIM(SKU), '')    
                  ,@c_Temp_Lot = ISNULL(RTRIM(Lot), '')    
                  ,@c_Temp_FromLoc = ISNULL(RTRIM(FromLoc), '')    
                  ,@c_Temp_FromID = ISNULL(RTRIM(FromID), '')    
                  ,@c_Temp_ToLoc = ISNULL(RTRIM(ToLoc), '')    
                  ,@c_Temp_ToID = ISNULL(RTRIM(ToID), '')    
                  ,@n_Temp_Qty = Qty    
            FROM #TempMoveRecord WITH (NOLOCK)    
            WHERE OrderLineNumber = @c_Temp_OrderLineNumber    
    
            IF @b_Debug = 1    
            BEGIN    
               PRINT '[isp1586P_WSIML_CN_Skechers_CancOrd_Import]: @c_Temp_Sku=' + @c_Temp_Sku    
                     + ', @c_Temp_Lot=' + @c_Temp_Lot + ', @c_Temp_ToLoc=' + @c_Temp_ToLoc +    
                     + ', @n_Temp_Qty=' + CAST(CAST(@n_Temp_Qty AS INT)AS NVARCHAR)    
            END    
    
            EXEC nspItrnAddMove    
               NULL    
            ,@c_StorerKey    
            ,@c_Temp_Sku    
            ,@c_Temp_Lot    
            ,@c_Temp_FromLoc    
            ,@c_Temp_FromID    
            ,@c_Temp_ToLoc    
            ,@c_Temp_ToID    
            ,NULL    
            ,'' --@c_lottable01    
            ,'' --@c_lottable02    
            ,'' --@c_lottable03    
            ,NULL --@d_lottable04    
            ,NULL --@d_lottable05    
            ,'' --@c_lottable06    
            ,'' --@c_lottable07    
            ,'' --@c_lottable08    
            ,'' --@c_lottable09    
            ,'' --@c_lottable10    
            ,'' --@c_lottable11    
            ,'' --@c_lottable12    
            ,NULL --@d_lottable13    
            ,NULL --@d_lottable14    
            ,NULL --@d_lottable15    
            ,0    
            ,0    
            ,@n_Temp_Qty    
            ,0    
            ,0    
            ,0    
            ,0    
            ,0    
            ,0    
            ,''    
            ,'isp_MoveStock'    
            ,'' --@c_PackKey    
            ,'' --@c_UOM    
            ,1    
            ,@dt_Temp_Datetime --@d_today    
            ,'' --@c_itrnkey    
            ,@b_Success OUTPUT    
            ,@n_Err OUTPUT    
            ,@c_ErrMsg OUTPUT    
    
    
            FETCH NEXT FROM C_TempMoveRecord_Loop INTO @c_Temp_OrderLineNumber    
         END -- WHILE @@FETCH_STATUS <> -1    
         CLOSE C_TempMoveRecord_Loop    
         DEALLOCATE C_TempMoveRecord_Loop    
    
         TRUNCATE TABLE #TempMoveRecord    
      END    
      /*********************************************/    
      /* Generate Move Back To Inventory (End)    */    
      /*********************************************/    
   END --IF @c_OrderStatus > '0'    
    
   /*********************************************/    
   /* Delete PreAllocatePickDetail (Start)      */    
   /*********************************************/    
   IF @c_SC_SValue = '0' OR @c_SC_SValue = ''    
   BEGIN    
      IF CURSOR_STATUS('LOCAL' , 'C_PreAllocatePickDetail_Delete') in (0 , 1)    
      BEGIN    
         CLOSE C_PreAllocatePickDetail_Delete    
         DEALLOCATE C_PreAllocatePickDetail_Delete    
      END    
    
      SET @c_PreAllocatePickDetailKey = ''    
    
      DECLARE C_PreAllocatePickDetail_Delete CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
         SELECT PreAllocatePickDetailKey    
         FROM PreAllocatePickDetail WITH (NOLOCK)    
         WHERE Orderkey = @c_Orderkey    
         AND StorerKey = @c_StorerKey    
         ORDER BY PreAllocatePickDetailKey    
    
      OPEN C_PreAllocatePickDetail_Delete    
      FETCH NEXT FROM C_PreAllocatePickDetail_Delete INTO @c_PreAllocatePickDetailKey    
    
      WHILE @@FETCH_STATUS <> -1    
      BEGIN    
         SET @c_ITFErrMsg = 'Start Delete PreAllocatePickDetail for PreAllocatePickDetailKey=' + @c_PreAllocatePickDetailKey --(KT04)    
    
         DELETE PreAllocatePickDetail    
            WHERE PreAllocatePickDetailKey = @c_PreAllocatePickDetailKey    
    
         IF @@ERROR <> 0    
         BEGIN    
            SET @c_InvalidFlag = 'Y'    
            SET @c_InstOutLog = 'Y'    
            SET @n_Err = 68123    
            SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0))    
                           + ': Fail To Unallocate OrderKey = ' + @c_OrderKey    
                           + '. Delete PreAllocatePickDetail Fail. (isp_FinalizePendingCancel)'    
    
            GOTO PROCESS_UPDATE    
         END    
    
         WHILE @@TRANCOUNT > 0    
            COMMIT TRAN    
    
         SET @c_ITFErrMsg = 'Success Delete PreAllocatePickDetail for PreAllocatePickDetailKey=' + @c_PreAllocatePickDetailKey    
    
         FETCH NEXT FROM C_PreAllocatePickDetail_Delete INTO @c_PreAllocatePickDetailKey    
      END -- WHILE @@FETCH_STATUS <> -1    
      CLOSE C_PreAllocatePickDetail_Delete    
      DEALLOCATE C_PreAllocatePickDetail_Delete    
   END --IF @c_SC_SValue = '0' OR @c_SC_SValue = ''    
   /*********************************************/    
   /* Delete PreAllocatePickDetail (End)        */    
   /*********************************************/    
   /* Delete LoadPlanDetail (Start)             */    
   /*********************************************/    
   IF CURSOR_STATUS('LOCAL' , 'C_LoadPlanDetail_Delete') in (0 , 1)    
   BEGIN    
      CLOSE C_LoadPlanDetail_Delete    
      DEALLOCATE C_LoadPlanDetail_Delete    
   END    
    
   DECLARE C_LoadPlanDetail_Delete CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
      SELECT LoadKey, LoadLineNumber    
      FROM LoadPlanDetail WITH (NOLOCK)    
      WHERE OrderKey = @c_Orderkey    
      ORDER BY LoadKey, LoadLineNumber    
    
   SET @c_ExecArguments = '@c_Orderkey NVARCHAR(10)'    
    
   EXEC sp_ExecuteSql @c_ExecStatements    
                     , @c_ExecArguments    
                     , @c_Orderkey    
    
   OPEN C_LoadPlanDetail_Delete    
   FETCH NEXT FROM C_LoadPlanDetail_Delete INTO @c_LoadKey, @c_LoadLineNumber    
    
   WHILE @@FETCH_STATUS <> -1    
   BEGIN    
      DELETE LoadPlanDetail    
      WHERE LoadKey = @c_LoadKey AND LoadLineNumber = @c_LoadLineNumber    
    
      IF @@ERROR <> 0    
      BEGIN    
         SET @c_InvalidFlag = 'Y'    
         SET @c_InstOutLog = 'Y'    
         SET @n_Err = 68124    
         SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0))    
                        + ': Delete LoadPlanDetail Fail for ExternOrderKey' + @c_ExternOrderKey    
                        + '. (isp_FinalizePendingCancel)'    
         GOTO PROCESS_UPDATE    
      END    
    
      WHILE @@TRANCOUNT > 0    
         COMMIT TRAN    
    
      FETCH NEXT FROM C_LoadPlanDetail_Delete INTO @c_LoadKey, @c_LoadLineNumber    
   END -- WHILE @@FETCH_STATUS <> -1    
   CLOSE C_LoadPlanDetail_Delete    
   DEALLOCATE C_LoadPlanDetail_Delete    
   /*********************************************/    
   /* Delete LoadPlanDetail (End)               */    
   /*********************************************/    
   /* Release CartonTrack (Start)               */    
   /*********************************************/    
   IF CURSOR_STATUS('LOCAL' , 'C_CartonTrackList_Delete') in (0 , 1)    
   BEGIN    
      CLOSE C_CartonTrackList_Delete    
      DEALLOCATE C_CartonTrackList_Delete    
   END    
    
   DECLARE C_CartonTrackList_Delete CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
      SELECT RowRef    
      FROM CartonTrack WITH (NOLOCK)    
      WHERE LabelNo = @c_Orderkey    
      ORDER BY RowRef    
    
   OPEN C_CartonTrackList_Delete    
   FETCH NEXT FROM C_CartonTrackList_Delete INTO @n_RowRef    
    
   WHILE @@FETCH_STATUS <> -1    
   BEGIN    
      SET @c_CT_TrackingNo = ''    
      SET @c_CT_EditWho = ''    
      SET @c_CT_EditDate = ''    
    
      SELECT @c_CT_TrackingNo = ISNULL(RTRIM(TrackingNo), '')    
         ,@c_CT_EditWho = ISNULL(RTRIM(EditWho), '')    
            ,@c_CT_EditDate = CONVERT(NVARCHAR(30), EditDate, 120)    
         FROM CartonTrack WITH (NOLOCK)    
         WHERE RowRef = @n_RowRef    
    
      UPDATE CartonTrack WITH (ROWLOCK)    
         SET LabelNo = ''    
      ,CarrierRef2 = 'PEND'    
      ,EditDate = GETDATE()    
      ,EditWho = SUSER_NAME()    
         WHERE RowRef = @n_RowRef    
    
      IF @@ERROR <> 0    
      BEGIN    
         SET @c_InvalidFlag = 'Y'    
         SET @c_InstOutLog = 'Y'    
         SET @n_Err = 68124    
         SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0))    
                        + ': Update CartonTrack Fail for ExternOrderKey' + @c_ExternOrderKey    
                        + '. (isp_FinalizePendingCancel)'    
         GOTO PROCESS_UPDATE    
      END    
          WHILE @@TRANCOUNT > 0    
         COMMIT TRAN    
    
      FETCH NEXT FROM C_CartonTrackList_Delete INTO @n_RowRef    
   END -- WHILE @@FETCH_STATUS <> -1    
   CLOSE C_CartonTrackList_Delete    
   DEALLOCATE C_CartonTrackList_Delete    
    
    
   /*********************************************/    
   /* Release CartonTrack (End)                 */    
   /*********************************************/    
   /* Release rdtTrackLog (Start)               */    
   /*********************************************/    
   IF CURSOR_STATUS('LOCAL' , 'C_rdtTrackLog_Delete') in (0 , 1)    
   BEGIN    
      CLOSE C_rdtTrackLog_Delete    
      DEALLOCATE C_rdtTrackLog_Delete    
   END    
    
   DECLARE C_rdtTrackLog_Delete CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
      SELECT RowRef    
      FROM RDT.rdtTrackLog WITH (NOLOCK)    
      WHERE OrderKey = @c_Orderkey    
      AND StorerKey = @c_StorerKey    
      ORDER BY RowRef    
    
   OPEN C_rdtTrackLog_Delete    
   FETCH NEXT FROM C_rdtTrackLog_Delete INTO @n_RowRef    
    
   WHILE @@FETCH_STATUS <> -1    
   BEGIN    
      DELETE RDT.rdtTrackLog WHERE RowRef = @n_RowRef    
    
      IF @@ERROR <> 0    
      BEGIN    
         SET @c_InvalidFlag = 'Y'    
         SET @c_InstOutLog = 'Y'    
         SET @n_Err = 68124    
         SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0))    
                        + ': Delete RDT.rdtTrackLog Fail for ExternOrderKey' + @c_ExternOrderKey    
                        + '. (isp_FinalizePendingCancel)'    
         GOTO PROCESS_UPDATE    
      END    
    
      WHILE @@TRANCOUNT > 0    
         COMMIT TRAN    
    
      FETCH NEXT FROM C_rdtTrackLog_Delete INTO @n_RowRef    
   END -- WHILE @@FETCH_STATUS <> -1    
   CLOSE C_rdtTrackLog_Delete    
   DEALLOCATE C_rdtTrackLog_Delete    
   /*********************************************/    
   /* Release rdtTrackLog (End)                 */    
   /*********************************************/    
   /* Update Orders.Status = CANC (Start)       */    
   /*********************************************/    
   SET @c_OrderStatus = 'CANC'    
   SET @c_SOStatus = 'CANC'    
    
   SET @c_ExecStatements= ''    
   UPDATE .ORDERS WITH (ROWLOCK)    
      SET EditWho = SUSER_NAME()    
      , EditDate = GETDATE()    
      , Status = @c_OrderStatus    
      , SOStatus = @c_SOStatus    
      , UserDefine04 = CASE WHEN @c_SC_SValue2 = '0' THEN '' ELSE UserDefine04 END    
      , TrackingNo = CASE WHEN @c_SC_SValue2 = '0' THEN '' ELSE TrackingNo END    
   WHERE Orderkey = @c_Orderkey    
    
   IF @@ERROR <> 0    
   BEGIN    
      SET @c_InvalidFlag = 'Y'    
      SET @c_InstOutLog = 'Y'    
      SET @n_Err = 80015    
      SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0))    
                     + ': Update Order Status Fail for ExternOrderKey' + @c_ExternOrderKey    
                     + '. (isp_FinalizePendingCancel)'    
      GOTO PROCESS_UPDATE    
   END    
   /*********************************************/    
   /* Update Orders.Status = CANC (End)         */    
   /*********************************************/    
    
   /*********************************************/    
   /* Update Order Detail (Start)               */    
   /*********************************************/    
   IF @c_UpdOrdDetField <> ''    
   BEGIN    
      SET @c_ColumnName1 = ''    
      SET @c_ColumnValue1 = ''    
   SET @c_ExecStatements1 = ''    
    
      SET @c_ColumnName1 = SUBSTRING(@c_UpdOrdDetField, 1, (CHARINDEX(':', @c_UpdOrdDetField) - 1))    
      SET @c_ColumnValue1 = SUBSTRING(@c_UpdOrdDetField, (CHARINDEX(':', @c_UpdOrdDetField) + 1),    
                              (LEN(@c_UpdOrdDetField) - CHARINDEX(':', @c_UpdOrdDetField)))    
    
      IF @b_debug = 1    
      BEGIN    
         PRINT '[isp_FinalizePendingCancel]: @c_ColumnName1=' + @c_ColumnName1    
         PRINT '[isp_FinalizePendingCancel]: @c_ColumnValue1=' + @c_ColumnValue1    
      END    
    
      SET @c_ExecStatements1 = @c_ColumnName1 + ' = ' +  QUOTENAME(@c_ColumnValue1, '''')    
    
    
      IF @c_ExecStatements1 <> ''    
      BEGIN    
         IF CURSOR_STATUS('LOCAL' , 'C_OrdDetUpdLoop') in (0 , 1)    
         BEGIN    
            CLOSE C_OrdDetUpdLoop    
            DEALLOCATE C_OrdDetUpdLoop    
         END    
    
         SET @c_OD_OrderLineNumber = ''    
    
         DECLARE C_OrdDetUpdLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
            SELECT ISNULL(RTRIM(OrderLineNumber), '')    
            FROM ORDERDETAIL WITH (NOLOCK)    
            WHERE OrderKey = @c_OrderKey    
            AND StorerKey = @c_StorerKey    
            ORDER BY ISNULL(RTRIM(OrderLineNumber), '')    
    
         OPEN C_OrdDetUpdLoop    
         FETCH NEXT FROM C_OrdDetUpdLoop INTO @c_OD_OrderLineNumber    
         WHILE @@FETCH_STATUS <> -1    
         BEGIN    
            IF @b_Debug = 1    
            BEGIN    
               PRINT '[isp_FinalizePendingCancel]: @c_OD_OrderLineNumber=' + @c_OD_OrderLineNumber    
            END    
    
            SET @c_ExecStatements = 'UPDATE ORDERDETAIL WITH (ROWLOCK)'    
                                    + ' SET EditWho = SUSER_NAME()'    
                                    + ', EditDate = GETDATE()'    
                                    + ', TrafficCop = NULL'    
                                    + ', ' + @c_ExecStatements1    
                                    + ' WHERE Orderkey = @c_Orderkey'    
                                    + ' AND OrderLineNumber = @c_OD_OrderLineNumber'    
    
            SET @c_ExecArguments = '@c_Orderkey NVARCHAR(10)'    
                                 + ',@c_OD_OrderLineNumber NVARCHAR(5)'    
    
    
            EXEC sp_ExecuteSql @c_ExecStatements    
                              , @c_ExecArguments    
                              , @c_Orderkey    
                              , @c_OD_OrderLineNumber    
    
    
            IF @@ERROR <> 0    
            BEGIN    
               SET @c_InvalidFlag = 'Y'    
               SET @c_InstOutLog = 'Y'    
               SET @n_Err = 80015    
               SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0))    
                              + ': Update Order Detail Fail for Order OrderKey=' + @c_Orderkey    
                              + '. (isp_FinalizePendingCancel)'    
               GOTO PROCESS_UPDATE    
            END    
    
            WHILE @@TRANCOUNT > 0    
               COMMIT TRAN    
    
            FETCH NEXT FROM C_OrdDetUpdLoop INTO @c_OD_OrderLineNumber    
         END -- WHILE @@FETCH_STATUS <> -1    
         CLOSE C_OrdDetUpdLoop    
         DEALLOCATE C_OrdDetUpdLoop    
      END --IF @c_ExecStatements1 <> ''    
   END --IF @c_UpdOrdDetField <> ''    
   /*********************************************/    
   /* Update Order Detail (End)                 */    
   /*********************************************/    
   /*********************************************/    
   /* Delete Child Order (Start)                */    
   /*********************************************/    
   IF @c_OrderGroup = 'CHILD_ORD'    
   BEGIN    
      IF @b_Debug = 1    
      BEGIN    
         PRINT '[isp_FinalizePendingCancel]: Start Delete Child Order...'    
      END    
    
      SET @c_OrderStatus = 'CANC'    
      SET @c_SOStatus = 'CANC'    
    
      UPDATE ORDERS WITH (ROWLOCK)    
         SET EditWho = SUSER_NAME()    
         , EditDate = GETDATE()    
         , Status = @c_OrderStatus    
         , SOStatus = @c_SOStatus    
         , UserDefine04 = CASE WHEN @c_SC_SValue2 = '0' THEN '' ELSE UserDefine04 END    
         , TrackingNo = CASE WHEN @c_SC_SValue2 = '0' THEN '' ELSE TrackingNo END    
         , OrderGroup = ''    
         WHERE Orderkey = @c_ChildOrderKey    
    
      IF @@ERROR <> 0    
      BEGIN    
         SET @c_InvalidFlag = 'Y'    
         SET @c_InstOutLog = 'Y'    
         SET @n_Err = 80015    
         SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0))    
                        + ': Update Order Status Fail for ExternOrderKey' + @c_ExternOrderKey    
                        + '. (isp_FinalizePendingCancel)'    
         GOTO PROCESS_UPDATE    
      END    
   END --IF @c_OrderGroup = 'CHILD_ORD'    
   /*********************************************/    
   /* Delete Child Order (End)                  */    
   /*********************************************/    
   /* Release Child Order (Start)               */    
   /*********************************************/    
   IF @c_OrderGroup = 'CHILD_ORD'    
   BEGIN    
      IF @b_Debug = 1    
      BEGIN    
         PRINT '[isp_FinalizePendingCancel]: Start Reset Order Detail...'    
      END    
    
      IF CURSOR_STATUS('LOCAL' , 'C_ChildOrdLoop') in (0 , 1)    
      BEGIN    
         CLOSE C_ChildOrdLoop    
         DEALLOCATE C_ChildOrdLoop    
      END    
    
      SET @c_SOStatus = 'PENDCOMB'    
      SET @c_Prev_ChildOrderKey = ''    
    
      DECLARE C_ChildOrdLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
         SELECT ISNULL(RTRIM(OrderKey), '')    
                ,ISNULL(RTRIM(OrderLineNumber), '')    
         FROM ORDERDETAIL WITH (NOLOCK)    
         WHERE ConsoOrderKey = @c_OrderKey    
         AND StorerKey = @c_StorerKey    
         AND Status <> 'CANC'    
         ORDER BY ISNULL(RTRIM(OrderKey), ''), ISNULL(RTRIM(OrderLineNumber), '')    
    
      SET @c_ExecArguments = N'@c_Orderkey   NVARCHAR(10)'    
                           + ',@c_StorerKey  NVARCHAR(15)'    
    
      EXEC sp_ExecuteSql @c_ExecStatements    
                        , @c_ExecArguments    
                        , @c_Orderkey    
                        , @c_StorerKey    
    
      OPEN C_ChildOrdLoop    
      FETCH NEXT FROM C_ChildOrdLoop INTO @c_DB_ChildOrderKey, @c_DB_ChildOrderLineNumber    
      WHILE @@FETCH_STATUS <> -1    
      BEGIN    
         IF @b_Debug = 1    
         BEGIN    
            PRINT '[isp_FinalizePendingCancel]: @c_DB_ChildOrderKey=' + @c_DB_ChildOrderKey    
                  + ', @c_DB_ChildOrderLineNumber=' + @c_DB_ChildOrderLineNumber    
         END    
    
         /*********************************************/    
         /* Update Child Order Header (Start)         */    
         /*********************************************/    
         IF @c_Prev_ChildOrderKey <> @c_DB_ChildOrderKey    
         BEGIN    
            SET @c_Prev_ChildOrderKey = @c_DB_ChildOrderKey    
    
            UPDATE ORDERS WITH (ROWLOCK)    
               SET EditWho = SUSER_NAME()    
            , EditDate = GETDATE()    
            , OrderGroup = ''    
            , SOStatus = @c_SOStatus    
            , TrafficCop = NULL    
               WHERE Orderkey = @c_DB_ChildOrderKey    
    
            IF @@ERROR <> 0    
            BEGIN    
               SET @c_InvalidFlag = 'Y'    
 SET @c_InstOutLog = 'Y'    
               SET @n_Err = 80015    
               SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0))    
                              + ': Update Order Header Status Fail for Child Order OrderKey=' + @c_DB_ChildOrderKey    
                              + '. (isp_FinalizePendingCancel)'    
               GOTO PROCESS_UPDATE    
            END    
         END --IF @c_Prev_ChildOrderKey <> @c_DB_ChildOrderKey    
         /*********************************************/    
         /* Update Child Order Header (End)           */    
         /*********************************************/    
         /* Update Child Order Detail (Start)         */    
         /*********************************************/    
         UPDATE ORDERDETAIL WITH (ROWLOCK)    
            SET EditWho = SUSER_NAME()    
               , EditDate = GETDATE()    
               , [Status] = '0'    
               , ConsoOrderKey = NULL    
               , ExternConsoOrderKey = NULL    
               , TrafficCop = NULL    
            WHERE Orderkey = @c_DB_ChildOrderKey    
            AND OrderLineNumber = @c_DB_ChildOrderLineNumber    
    
    
         IF @@ERROR <> 0    
         BEGIN    
            SET @c_InvalidFlag = 'Y'    
            SET @c_InstOutLog = 'Y'    
            SET @n_Err = 80015    
            SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0))    
                           + ': Update Order Detail Fail for Child Order OrderKey=' + @c_DB_ChildOrderKey    
                           + '. (isp_FinalizePendingCancel)'    
            GOTO PROCESS_UPDATE    
         END    
         /*********************************************/    
         /* Update Child Order Detail (End)           */    
         /*********************************************/    
    
         WHILE @@TRANCOUNT > 0    
            COMMIT TRAN    
    
         FETCH NEXT FROM C_ChildOrdLoop INTO @c_DB_ChildOrderKey, @c_DB_ChildOrderLineNumber    
      END -- WHILE @@FETCH_STATUS <> -1    
      CLOSE C_ChildOrdLoop    
      DEALLOCATE C_ChildOrdLoop    
   END --IF @c_OrderGroup = 'CHILD_ORD'    
   /*********************************************/    
   /* Release Child Order (Start)               */    
   /*********************************************/    
    
   WHILE @@TRANCOUNT > 0    
   BEGIN    
      COMMIT TRAN    
   END    
   /*********************************************/    
   /* Update Order Status (End)                 */    
   /*********************************************/    
    
   PROCESS_UPDATE:    
    
   IF CURSOR_STATUS('LOCAL' , 'C_PickingInfo_Delete') in (0 , 1)    
   BEGIN    
      CLOSE C_PickingInfo_Delete    
      DEALLOCATE C_PickingInfo_Delete    
   END    
    
   IF CURSOR_STATUS('LOCAL' , 'C_PickDetail_Delete') in (0 , 1)    
   BEGIN    
      CLOSE C_PickDetail_Delete    
      DEALLOCATE C_PickDetail_Delete    
   END    
    
   IF CURSOR_STATUS('LOCAL' , 'C_PickHeader_Delete') in (0 , 1)    
   BEGIN    
      CLOSE C_PickHeader_Delete    
      DEALLOCATE C_PickHeader_Delete    
   END    
    
   IF CURSOR_STATUS('LOCAL' , 'C_PackInfo_Delete') in (0 , 1)    
   BEGIN    
      CLOSE C_PackInfo_Delete    
      DEALLOCATE C_PackInfo_Delete    
   END    
    
   IF CURSOR_STATUS('LOCAL' , 'C_PackHeader_Delete') in (0 , 1)    
   BEGIN    
      CLOSE C_PackHeader_Delete    
      DEALLOCATE C_PackHeader_Delete    
   END    
    
   IF CURSOR_STATUS('LOCAL' , 'C_PackDetail_Delete') in (0 , 1)    
   BEGIN    
      CLOSE C_PackDetail_Delete    
      DEALLOCATE C_PackDetail_Delete    
   END    
    
   IF CURSOR_STATUS('LOCAL' , 'C_LoadPlanDetail_Delete') in (0 , 1)    
   BEGIN    
      CLOSE C_LoadPlanDetail_Delete    
      DEALLOCATE C_LoadPlanDetail_Delete    
   END    
    
   IF CURSOR_STATUS('LOCAL' , 'C_CartonTrackList_Delete') in (0 , 1)    
   BEGIN    
      CLOSE C_CartonTrackList_Delete    
      DEALLOCATE C_CartonTrackList_Delete    
   END    
    
   IF CURSOR_STATUS('LOCAL' , 'C_PreAllocatePickDetail_Delete') in (0 , 1)    
   BEGIN    
      CLOSE C_PreAllocatePickDetail_Delete    
      DEALLOCATE C_PreAllocatePickDetail_Delete    
   END    
    
   IF CURSOR_STATUS('LOCAL' , 'C_rdtTrackLog_Delete') in (0 , 1)    
   BEGIN    
      CLOSE C_rdtTrackLog_Delete    
      DEALLOCATE C_rdtTrackLog_Delete    
   END    
    
   IF CURSOR_STATUS('LOCAL' , 'C_TempMoveRecord_Loop') in (0 , 1)    
   BEGIN    
      CLOSE C_TempMoveRecord_Loop    
      DEALLOCATE C_TempMoveRecord_Loop    
   END    
    
   IF CURSOR_STATUS('LOCAL' , 'C_ChildOrdLoop') in (0 , 1)    
   BEGIN    
      CLOSE C_ChildOrdLoop    
      DEALLOCATE C_ChildOrdLoop    
   END    
    
END

GO