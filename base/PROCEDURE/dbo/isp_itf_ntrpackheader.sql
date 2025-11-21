SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store Procedure:  isp_ITF_ntrPackHeader                              */  
/* Creation Date: 23-Aug-2017                                           */  
/* Copyright: LF                                                        */  
/* Written by: YokeBeen                                                 */  
/*                                                                      */  
/* Purpose:  Handling trigger points for Pack's module.                 */  
/*           Including Pack Header trigger points for Add & Update.     */  
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
/*             - ntrPackHeaderUpdate                                    */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/* Date         Author    Ver.  Purposes                                */  
/* 11-Oct-2017  MCTang    1.0   Enhancement (MC02)                      */
/************************************************************************/  

CREATE PROC [dbo].[isp_ITF_ntrPackHeader]  
            @c_TriggerName          NVARCHAR(120)  
          , @c_SourceTable          NVARCHAR(60)  
          , @c_PickSlipNo           NVARCHAR(10)  
          , @b_ColumnsUpdated       VARBINARY(1000)             
          , @b_Success              INT           OUTPUT  
          , @n_err                  INT           OUTPUT  
          , @c_errmsg               NVARCHAR(250) OUTPUT  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF 
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   /********************************************************/  
   /* Variables Declaration & Initialization - (Start)     */  
   /********************************************************/  
   DECLARE @n_continue              INT    
         , @n_StartTCnt             INT     -- Holds the current transaction count  
  
   -- ITFTriggerConfig table  
   DECLARE @c_ConfigKey             NVARCHAR(30)  
         , @c_Tablename             NVARCHAR(30)  
         , @c_Tablename2            NVARCHAR(30) 
         , @c_RecordType            NVARCHAR(10)  
         , @c_RecordStatus          NVARCHAR(10)  
         , @c_sValue                NVARCHAR(10)  
         , @c_TargetTable           NVARCHAR(60)  
         , @c_StoredProc            NVARCHAR(200)  
         , @c_ConfigFacility        NVARCHAR(5)
         , @c_UpdatedColumns        NVARCHAR(250)      
  
   -- PACKHEADER / TransmitLog3 tables  
   DECLARE @c_StorerKey             NVARCHAR(15)  
         , @c_OrderKey              NVARCHAR(10)  
         , @c_LoadKey               NVARCHAR(10)  
         , @c_Status                NVARCHAR(10)  
         , @c_Key1                  NVARCHAR(10)
         , @c_Key2                  NVARCHAR(30)

   DECLARE @b_debug int
   SET @b_debug = 0
  
   SET @c_OrderKey = ''
   SET @c_LoadKey = ''
   SET @c_Status = ''
   SET @c_Key1 = ''
   SET @c_Key2 = ''
   SET @c_Tablename = ''

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
      (ISNULL(RTRIM(@c_PickSlipNo),'') = '')  
   BEGIN  
      RETURN  
   END  
  
   IF (ISNULL(RTRIM(@c_TriggerName),'') <> 'ntrPackHeaderUpdate')  
   BEGIN  
      RETURN  
   END  
  
   IF (ISNULL(RTRIM(@c_SourceTable),'') <> 'PackHeader')  
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
      IF ISNULL(RTRIM(@c_TriggerName),'') = 'ntrPackHeaderUpdate'
      BEGIN
         SELECT @c_StorerKey     = ISNULL(RTRIM(PackHeader.StorerKey),'')  
              , @c_OrderKey      = ISNULL(RTRIM(PackHeader.OrderKey),'')   
              , @c_LoadKey       = ISNULL(RTRIM(PackHeader.LoadKey),'')   
              , @c_Status        = ISNULL(RTRIM(PackHeader.Status),'')   
          FROM PackHeader WITH (NOLOCK)   
         WHERE PackHeader.PickSlipNo = @c_PickSlipNo  
      END
   END   
   /*************************************************************************************/  
   /* Std - Extract values for required variables (End)                                 */  
   /*************************************************************************************/  
     
   /********************************************/  
   /* Main Program (Start)                     */  
   /********************************************/  
   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN  
      IF EXISTS ( SELECT 1 FROM ITFTriggerConfig WITH (NOLOCK)    
                  WHERE StorerKey   = @c_StorerKey   
                  AND   SourceTable = @c_SourceTable  
                  AND   sValue      = '1' )  
      BEGIN   
         DECLARE Cur_ITFTriggerConfig_Pack CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
         SELECT  DISTINCT ConfigKey  
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
  
         OPEN Cur_ITFTriggerConfig_Pack  
         FETCH NEXT FROM Cur_ITFTriggerConfig_Pack INTO @c_ConfigKey, @c_ConfigFacility, @c_Tablename, @c_RecordType, @c_RecordStatus  
                                                      , @c_sValue, @c_TargetTable, @c_StoredProc, @c_UpdatedColumns   
  
         WHILE @@FETCH_STATUS <> -1  
         BEGIN 
            SET @b_Success = 0 
               
            IF ISNULL(RTRIM(@c_TriggerName),'') = 'ntrPackHeaderUpdate'
            BEGIN 
               IF @b_debug = 1
               BEGIN
                  SELECT 'Check #1 -- @c_ConfigKey: ' + @c_ConfigKey , '@c_UpdatedColumns: ' + @c_UpdatedColumns , 
                         '@c_Key2: ' + @c_Key2 , '@c_Key2: ' + @c_Key2 , '@c_Tablename = ' + @c_Tablename
               END 

               IF ISNULL(RTRIM(@c_UpdatedColumns), '') <> ''
               BEGIN
                  IF NOT EXISTS(SELECT 1 FROM 
                                dbo.fnc_GetUpdatedColumns(@c_SourceTable, @b_ColumnsUpdated) 
                                WHERE COLUMN_NAME IN ( SELECT ColValue FROM dbo.fnc_DelimSplit(',', @c_UpdatedColumns)))
                  BEGIN
                     IF @b_debug = 1
                     BEGIN
                        PRINT 'Not Exists'
                     END 

                     GOTO Get_Next_Config
                  END 
               END
            END

            IF ISNULL(@c_ConfigFacility,'') = ''
            BEGIN 
               IF ISNULL(RTRIM(@c_OrderKey), '') <> ''
               BEGIN
                  -- SOS#252143 - Add PACKEDLOG (MC01)
                  IF ISNULL(RTRIM(@c_ConfigKey),'') = 'PACKEDLOG'
                  BEGIN 
                     SET @c_Key1 = @c_OrderKey
                  END -- IF ISNULL(RTRIM(@c_ConfigKey),'') = 'PACKEDLOG'
                  -- FBR365438-CN-LULU-Fedex. Add PACKED2LOG to Transmitlog3 (NJOW07)
                  ELSE IF ISNULL(RTRIM(@c_ConfigKey),'') = 'PACKED2LOG'
                  BEGIN 
                     SET @c_Key1 = @c_OrderKey
                  END -- IF ISNULL(RTRIM(@c_ConfigKey),'') = 'PACKED2LOG'
                  ELSE IF ISNULL(RTRIM(@c_ConfigKey),'') = 'PACKCFMLOG'
                  BEGIN 
                     SET @c_Key1 = @c_PickSlipNo
                     SET @c_key2 = 'O' + @c_OrderKey
                  END -- IF ISNULL(RTRIM(@c_ConfigKey),'') = 'PACKCFMLOG'
                  --(MC02) - S
                  ELSE
                  BEGIN
                     SET @c_Key1 = @c_PickSlipNo
                     SET @c_key2 = 'O' + @c_OrderKey                     
                  END
                  --(MC02) - E
               END -- IF ISNULL(RTRIM(@c_OrderKey), '') <> ''
               ELSE
               IF ISNULL(RTRIM(@c_OrderKey), '') = '' AND ISNULL(RTRIM(@c_LoadKey),'') <> '' 
               BEGIN
                  IF ISNULL(RTRIM(@c_ConfigKey),'') = 'PACKCFMLOG'
                  BEGIN 
                     SET @c_Key1 = @c_PickSlipNo
                     SET @c_key2 = 'L' + @c_LoadKey
                  END -- IF ISNULL(RTRIM(@c_ConfigKey),'') = 'PACKCFMLOG'
                  --(MC02) - S
                  ELSE
                  BEGIN
                     SET @c_Key1 = @c_PickSlipNo
                     SET @c_key2 = 'L' + @c_LoadKey                     
                  END
                  --(MC02) - E
               END -- ISNULL(RTRIM(@c_OrderKey), '') = '' AND ISNULL(RTRIM(@c_LoadKey),'') <> '' 
            END -- IF ISNULL(@c_ConfigFacility,'') = ''


            IF ISNULL(RTRIM(@c_StoredProc),'') <> ''
            BEGIN
               EXEC sys.sp_executesql @c_StoredProc, N'@c_PickSlipNo NVARCHAR(10), @b_Success INT OUTPUT, @c_ErrNo INT OUTPUT, @c_ErrMsg NVARCHAR(215) OUTPUT',
                           @c_PickSlipNo, 
                           @b_Success OUTPUT, 
                           @n_Err     OUTPUT, 
                           @c_ErrMsg  OUTPUT 
            END
            ELSE
            BEGIN
               IF (@c_RecordStatus <> '' AND @c_RecordStatus = @c_Status AND UPPER(@c_UpdatedColumns) = 'STATUS') 
               BEGIN 
                  SET @b_Success = 1
               END
            END

            IF @b_Success = 1
            BEGIN
               GOTO Add_IntoTransmitLog
            END -- IF @b_Success = 1
            
/******************************************************************/
/* Records Insertion into selected TransmitLog table - (Start)    */
/******************************************************************/
            Add_IntoTransmitLog:
            IF @n_continue = 1 OR @n_continue = 2  
            BEGIN  
               IF @c_TargetTable = 'TRANSMITLOG2'   
               BEGIN  
                  EXEC ispGenTransmitLog2 @c_Tablename, @c_Key1, @c_Key2, @c_StorerKey, ''  
                                          , @b_success OUTPUT  
                                          , @n_err OUTPUT  
                                          , @c_errmsg OUTPUT  
                       
                  IF @b_success <> 1  
                  BEGIN  
                     SET @n_continue = 3  
                     SET @n_err = 68001  
                     SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0)) +   
                                       ': Insert into TRANSMITLOG2 Failed. (isp_ITF_ntrPackHeader) ( SQLSvr MESSAGE = ' +   
                                       ISNULL(LTRIM(RTRIM(@c_errmsg)),'') + ' ) '  
                     GOTO QUIT  
                  END   
               END -- IF @c_TargetTable = 'TRANSMITLOG2'  
               ELSE IF @c_TargetTable = 'TRANSMITLOG3'   
               BEGIN  
                  EXEC ispGenTransmitLog3 @c_Tablename, @c_Key1, @c_Key2, @c_StorerKey, ''  
                                          , @b_success OUTPUT  
                                          , @n_err OUTPUT  
                                          , @c_errmsg OUTPUT  
                       
                  IF @b_success <> 1  
                  BEGIN  
                     SET @n_continue = 3  
                     SET @n_err = 68001  
                     SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0)) +   
                                       ': Insert into TRANSMITLOG3 Failed. (isp_ITF_ntrPackHeader) ( SQLSvr MESSAGE = ' +   
                                       ISNULL(LTRIM(RTRIM(@c_errmsg)),'') + ' ) '  
                     GOTO QUIT  
                  END   
               END -- IF @c_TargetTable = 'TRANSMITLOG3'  
            END -- IF @n_continue = 1 OR @n_continue = 2  

            SET @c_Key1 = ''
            SET @c_Key2 = ''
            SET @c_Tablename = ''

            Get_Next_Config:
            FETCH NEXT FROM Cur_ITFTriggerConfig_Pack INTO @c_ConfigKey, @c_ConfigFacility, @c_Tablename, @c_RecordType, @c_RecordStatus  
                                                         , @c_sValue, @c_TargetTable, @c_StoredProc, @c_UpdatedColumns   
         END -- WHILE @@FETCH_STATUS <> -1  
         CLOSE Cur_ITFTriggerConfig_Pack  
         DEALLOCATE Cur_ITFTriggerConfig_Pack  
      END -- IF EXISTS ( SELECT 1 FROM ITFTriggerConfig WITH (NOLOCK)   
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
      EXECUTE dbo.nsp_logerror @n_err, @c_errmsg, 'isp_ITF_ntrPackHeader'  
  
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