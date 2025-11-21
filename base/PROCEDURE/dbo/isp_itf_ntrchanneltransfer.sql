SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
 

/************************************************************************/  
/* Store Procedure:  isp_ITF_ntrChannelTransfer                         */  
/* Creation Date: 18-Oct-2018                                           */  
/* Copyright: LF                                                        */  
/* Written by: YokeBeen                                                 */  
/*                                                                      */  
/* Purpose:  Handling trigger points for ChannelTransfer's module.      */  
/*           Including ChannelTransfer trigger points for Update.       */  
/*                                                                      */  
/* Input Parameters:   @c_TriggerName        - TriggerName              */  
/*                     @c_SourceTable        - SourceTable              */  
/*                     @c_FromStorerKey      - FromStorerKey            */  
/*                     @c_ToStorerKey        - ToStorerKey              */  
/*                     @c_ChannelTransferKey - ChannelTransferKey       */  
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
/*             - ntrChannelTransferUpdate                               */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 1.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/* Date         Author    Ver.  Purposes                                */  
/* DD-MMM-YYYY                                                          */  
/************************************************************************/  
  
CREATE PROC [dbo].[isp_ITF_ntrChannelTransfer]  
            @c_TriggerName          nvarchar(120)  
          , @c_SourceTable          nvarchar(60)  
          , @c_FromStorerKey        nvarchar(15)  
          , @c_ToStorerKey          nvarchar(15)  
          , @c_ChannelTransferKey   nvarchar(10)  
          , @b_Success              int           OUTPUT  
          , @n_err                  int           OUTPUT  
          , @c_errmsg               nvarchar(250) OUTPUT  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF 
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
/********************************************************/  
/* Variables Declaration & Initialization - (Start)     */  
/********************************************************/  
   DECLARE @n_continue              int    
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
  
   -- ChannelTransfer table  
   DECLARE @c_Type                  nvarchar(12)  
         , @c_ReasonCode            nvarchar(10)  
         , @c_Status                nvarchar(10)  
         , @c_Facility              nvarchar(5)  
  
   SET @n_StartTCnt = @@TRANCOUNT   
   SET @n_continue = 1   
   SET @b_success = 0   
   SET @n_err = 0   
   SET @c_errmsg = ''   
/********************************************************/  
/* Variables Declaration & Initialization - (End)       */  
/********************************************************/  
  
/*************************************************************************************/  
/* Std - Verify Parameter variables, no values found, return to core program (Start) */  
/*************************************************************************************/  
   IF (ISNULL(RTRIM(@c_TriggerName),'') = '') OR   
      (ISNULL(RTRIM(@c_SourceTable),'') = '') OR   
      (ISNULL(RTRIM(@c_FromStorerKey),'') = '') OR   
      (ISNULL(RTRIM(@c_ToStorerKey),'') = '') OR   
      (ISNULL(RTRIM(@c_ChannelTransferKey),'') = '')  
   BEGIN  
      RETURN  
   END  
  
   IF (ISNULL(RTRIM(@c_TriggerName),'') <> 'ntrChannelTransferUpdate')  
   BEGIN  
      RETURN  
   END  
  
   IF (ISNULL(RTRIM(@c_SourceTable),'') <> 'CHANNELTRANSFER')  
   BEGIN  
      RETURN  
   END  
/*************************************************************************************/  
/* Std - Verify Parameter variables, no values found, return to core program (End)   */  
/*************************************************************************************/  
  
  
/*************************************************************************************/  
/* Std - Extract values for required variables (Start)                               */  
/*************************************************************************************/  
   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN  
      SELECT @c_Type        = ISNULL(RTRIM(CHANNELTRANSFER.[Type]),'')  
           , @c_ReasonCode  = ISNULL(RTRIM(CHANNELTRANSFER.ReasonCode),'')   
           , @c_Status      = ISNULL(RTRIM(CHANNELTRANSFER.[Status]),'')   
           , @c_Facility    = ISNULL(RTRIM(CHANNELTRANSFER.Facility),'')   
        FROM CHANNELTRANSFER WITH (NOLOCK)   
       WHERE CHANNELTRANSFER.ChannelTransferKey = @c_ChannelTransferKey  
   END   
/*************************************************************************************/  
/* Std - Extract values for required variables (End)                                 */  
/*************************************************************************************/  
  
/********************************************/  
/* Main Program (Start)                     */  
/********************************************/  
   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN  
/**********************************************************************************************************************************************/  
/* Retrieve related info from ITFTriggerConfig table into a cursor for records triggering, base on CHANNELTRANSFER & FromStorerKey - (Start)  */  
/**********************************************************************************************************************************************/  
      IF EXISTS ( SELECT 1 FROM ITFTriggerConfig WITH (NOLOCK)    
                   WHERE StorerKey   = @c_FromStorerKey   
                     AND SourceTable = @c_SourceTable  
                     AND sValue      = '1' )  
      BEGIN   
         DECLARE Cur_ITFTriggerConfig_ChannelTRFFrom CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
          SELECT DISTINCT ConfigKey  
                        , Facility  
                        , Tablename  
                        , RecordType  
                        , RecordStatus  
                        , sValue  
                        , TargetTable  
                        , StoredProc  
            FROM ITFTriggerConfig WITH (NOLOCK)   
           WHERE StorerKey   = @c_FromStorerKey    
             AND SourceTable = @c_SourceTable  
             AND sValue      = '1'  
  
         OPEN Cur_ITFTriggerConfig_ChannelTRFFrom  
         FETCH NEXT FROM Cur_ITFTriggerConfig_ChannelTRFFrom INTO @c_ConfigKey, @c_ConfigFacility, @c_Tablename, @c_RecordType, @c_RecordStatus  
                                                                , @c_sValue, @c_TargetTable, @c_StoredProc  
  
         WHILE @@FETCH_STATUS <> -1  
         BEGIN  
            IF ISNULL(@c_ConfigFacility,'') = ''  
            BEGIN   
               IF @c_ConfigKey = 'CNLTRFFLOG' 
               BEGIN   
                  GOTO AddIntoTransmitLog_FromStorerKey  
               END -- IF @c_ConfigKey = 'CNLTRFFLOG'  
            END -- IF ISNULL(@c_ConfigFacility,'') = ''  
  
            GOTO Next_Record_FromStorerKey  
  
/*************************************************************************************/  
/* Records Insertion into selected TransmitLog table with FromStorerKey - (Start)    */  
/*************************************************************************************/  
   AddIntoTransmitLog_FromStorerKey:  
  
            IF @c_TargetTable = 'TRANSMITLOG3'  
            BEGIN  
               EXEC ispGenTransmitLog3 @c_Tablename, @c_ChannelTransferKey, @c_ReasonCode, @c_FromStorerKey, ''  
                                     , @b_success OUTPUT  
                                     , @n_err OUTPUT  
                                     , @c_errmsg OUTPUT  
                    
               IF @b_success <> 1  
               BEGIN  
                  SET @n_continue = 3  
                  SET @n_err = 68001  
                  SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0)) +   
                                  ': Insert into TRANSMITLOG3 Failed. (isp_ITF_ntrChannelTransfer) ( SQLSvr MESSAGE = ' +   
                                  ISNULL(LTRIM(RTRIM(@c_errmsg)),'') + ' ) '  
                  GOTO QUIT  
               END   
            END -- IF @c_TargetTable = 'TRANSMITLOG3'  
/*************************************************************************************/  
/* Records Insertion into selected TransmitLog table with FromStorerKey - (End)      */  
/*************************************************************************************/  
  
   Next_Record_FromStorerKey:  
            FETCH NEXT FROM Cur_ITFTriggerConfig_ChannelTRFFrom INTO @c_ConfigKey, @c_ConfigFacility, @c_Tablename, @c_RecordType, @c_RecordStatus  
                                                                   , @c_sValue, @c_TargetTable, @c_StoredProc  
         END -- WHILE @@FETCH_STATUS <> -1  
         CLOSE Cur_ITFTriggerConfig_ChannelTRFFrom  
         DEALLOCATE Cur_ITFTriggerConfig_ChannelTRFFrom  
      END -- SourceTable = 'TRANSFER' AND StorerKey = @c_FromStorerKey  
/**********************************************************************************************************************************************/  
/* Retrieve related info from ITFTriggerConfig table into a cursor for records triggering, base on CHANNELTRANSFER & FromStorerKey - (End)    */  
/**********************************************************************************************************************************************/  
  
/**********************************************************************************************************************************************/  
/* Retrieve related info from ITFTriggerConfig table into a cursor for records triggering, base on CHANNELTRANSFER & ToStorerKey - (Start)    */  
/**********************************************************************************************************************************************/  
      IF EXISTS ( SELECT 1 FROM ITFTriggerConfig WITH (NOLOCK)    
                   WHERE StorerKey   = @c_ToStorerKey   
                     AND SourceTable = @c_SourceTable  
                     AND sValue      = '1' )  
      BEGIN   
         DECLARE Cur_ITFTriggerConfig_ChannelTRFTo CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
          SELECT DISTINCT ConfigKey  
                        , Facility  
                        , Tablename  
                        , RecordType  
                        , RecordStatus  
                        , sValue  
                        , TargetTable  
                        , StoredProc  
            FROM ITFTriggerConfig WITH (NOLOCK)   
           WHERE StorerKey   = @c_ToStorerKey    
             AND SourceTable = @c_SourceTable  
             AND sValue      = '1'  
  
         OPEN Cur_ITFTriggerConfig_ChannelTRFTo  
         FETCH NEXT FROM Cur_ITFTriggerConfig_ChannelTRFTo INTO @c_ConfigKey, @c_ConfigFacility, @c_Tablename, @c_RecordType, @c_RecordStatus  
                                                              , @c_sValue, @c_TargetTable, @c_StoredProc  
  
         WHILE @@FETCH_STATUS <> -1  
         BEGIN  
            IF ISNULL(@c_ConfigFacility,'') = ''  
            BEGIN   
               IF @c_ConfigKey = 'CNLTRFLOG' 
               BEGIN   
                  GOTO AddIntoTransmitLog_ToStorerKey  
               END -- IF @c_ConfigKey = 'CNLTRFLOG'  
            END -- IF ISNULL(@c_ConfigFacility,'') = ''   
  
            GOTO Next_Record_ToStorerKey  
  
/*************************************************************************************/  
/* Records Insertion into selected TransmitLog table with FromStorerKey - (Start)    */  
/*************************************************************************************/  
   AddIntoTransmitLog_ToStorerKey:  
  
            IF @c_TargetTable = 'TRANSMITLOG3'  
            BEGIN  
               EXEC ispGenTransmitLog3 @c_Tablename, @c_ChannelTransferKey, @c_ReasonCode, @c_ToStorerKey, ''  
                                     , @b_success OUTPUT  
                                     , @n_err OUTPUT  
                                     , @c_errmsg OUTPUT  
                    
               IF @b_success <> 1  
               BEGIN  
                  SET @n_continue = 3  
                  SET @n_err = 68002  
                  SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0)) +   
                                  ': Insert into TRANSMITLOG3 Failed. (isp_ITF_ntrChannelTransfer) ( SQLSvr MESSAGE = ' +   
                                  ISNULL(LTRIM(RTRIM(@c_errmsg)),'') + ' ) '  
                  GOTO QUIT  
               END   
            END -- IF @c_TargetTable = 'TRANSMITLOG3'  
/*************************************************************************************/  
/* Records Insertion into selected TransmitLog table with FromStorerKey - (End)      */  
/*************************************************************************************/  
  
   Next_Record_ToStorerKey:  
            FETCH NEXT FROM Cur_ITFTriggerConfig_ChannelTRFTo INTO @c_ConfigKey, @c_ConfigFacility, @c_Tablename, @c_RecordType, @c_RecordStatus  
                                                                 , @c_sValue, @c_TargetTable, @c_StoredProc  
         END -- WHILE @@FETCH_STATUS <> -1  
         CLOSE Cur_ITFTriggerConfig_ChannelTRFTo  
         DEALLOCATE Cur_ITFTriggerConfig_ChannelTRFTo  
      END -- SourceTable = 'CHANNELTRANSFER' AND StorerKey = @c_ToStorerKey  
/**********************************************************************************************************************************************/  
/* Retrieve related info from ITFTriggerConfig table into a cursor for records triggering, base on CHANNELTRANSFER & ToStorerKey - (End)      */  
/**********************************************************************************************************************************************/  
  
   END -- IF @n_continue = 1 OR @n_continue = 2  
/********************************************/  
/* Main Program (End)                       */  
/********************************************/  
  
/********************************************/  
/* Std - Error Handling (Start)             */  
/********************************************/  
QUIT:  
  
   WHILE @@TRANCOUNT < @n_StartTCnt  
      BEGIN TRAN  
  
   IF @n_continue=3  -- Error Occured - Process And Return  
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
      EXECUTE dbo.nsp_logerror @n_err, @c_errmsg, 'isp_ITF_ntrChannelTransfer'  
  
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