SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/  
/* Store Procedure:  isp_ITF_ntrCartonTrack                             */  
/* Creation Date: 04-Jan-2017                                           */  
/* Copyright: LFL                                                       */  
/* Written by: KHChan                                                   */  
/*                                                                      */  
/* Purpose:  Handling trigger points for CartonTrack's module.          */  
/*           Including CartonTrack trigger points for Update.           */  
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
/*             - ntrCartonTrackUpdate                                   */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/* Date         Author    Ver.  Purposes                                */  
/************************************************************************/  
  
CREATE PROC [dbo].[isp_ITF_ntrCartonTrack]  
            @c_TriggerName          NVARCHAR(120)  
          , @c_SourceTable          NVARCHAR(60)
          , @n_RowRef               INT
          , @c_OrderKey             NVARCHAR(15)  
          , @c_StorerKey            NVARCHAR(15)
          , @c_ColumnsUpdated       VARCHAR(1000)
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
   DECLARE @n_continue              int    
         , @n_StartTCnt             int     -- Holds the current transaction count  
  
   -- ITFTriggerConfig table  
   DECLARE @c_ConfigKey   nvarchar(30)  
         , @c_Tablename             nvarchar(30)  
         , @c_Tablename2            nvarchar(30)
         , @c_RecordType            nvarchar(10)  
         , @c_RecordStatus          nvarchar(10)  
         , @c_sValue                nvarchar(10)  
         , @c_TargetTable           nvarchar(60)  
         , @c_StoredProc            nvarchar(200)  
         , @c_ConfigFacility        nvarchar(5)
         , @c_UpdatedColumns        NVARCHAR(250)      
  
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
      (ISNULL(RTRIM(@c_OrderKey),'') = '') OR
      (ISNULL(RTRIM(@c_StorerKey),'') = '') OR
      (@n_RowRef < 0)
   BEGIN  
      RETURN  
   END  
        
   IF (ISNULL(RTRIM(@c_TriggerName),'') <> 'ntrCartonTrackUpdate')  
   BEGIN  
      RETURN  
   END  
  
   IF (ISNULL(RTRIM(@c_SourceTable),'') <> 'CARTONTRACK')  
   BEGIN  
      RETURN  
   END  
   /*************************************************************************************/  
   /* Std - Verify Parameter variables, no values found, return to core program (End)   */  
   /*************************************************************************************/  
     
   /*************************************************************************************/  
   /* Std - Extract values for required variables (Start)                               */  
   /*************************************************************************************/  
   --IF @n_continue = 1 OR @n_continue = 2  
   --BEGIN  
   --   SELECT 
   --      FROM CARTONTRACK WITH (NOLOCK)   
   --   WHERE CARTONTRACK.RowRef = @n_RowRef  
   --END   
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
         DECLARE Cur_ITFTriggerConfig_Order CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
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
  
         OPEN Cur_ITFTriggerConfig_Order  
         FETCH NEXT FROM Cur_ITFTriggerConfig_Order INTO @c_ConfigKey, @c_ConfigFacility, @c_Tablename, @c_RecordType, @c_RecordStatus  
                                                         , @c_sValue, @c_TargetTable, @c_StoredProc, @c_UpdatedColumns   
  
         WHILE @@FETCH_STATUS <> -1  
         BEGIN 

            IF ISNULL(RTRIM(@c_TriggerName),'') = 'ntrCartonTrackUpdate'
            BEGIN 
               IF ISNULL(RTRIM(@c_UpdatedColumns), '') <> ''
               BEGIN
  
                  IF NOT EXISTS(SELECT 1 FROM                                                                              
                                dbo.fnc_DelimSplit(',', @c_ColumnsUpdated)                                           
                                WHERE ColValue IN (SELECT ColValue FROM dbo.fnc_DelimSplit(',', @c_UpdatedColumns))) 
                  BEGIN
                     GOTO Get_Next_Config
                  END 
               END
               ELSE
               BEGIN
                  GOTO Get_Next_Config
               END
            END
            
            IF ISNULL(RTRIM(@c_StoredProc),'') <> ''
            BEGIN
               SET @b_Success = 0 
               
               EXEC sys.sp_executesql @c_StoredProc, N'@n_RowRef INT, @b_Success INT OUTPUT, @c_ErrNo INT OUTPUT, @c_ErrMsg NVARCHAR(215) OUTPUT',
                           @n_RowRef, 
                           @b_Success OUTPUT, 
                           @n_err     OUTPUT, 
                           @c_errmsg  OUTPUT 
            END
   
            IF @b_Success = 1
            BEGIN
               IF @c_TargetTable = 'TRANSMITLOG3'   
               BEGIN  
                  EXEC ispGenTransmitLog3 @c_Tablename, @c_OrderKey, @n_RowRef, @c_StorerKey, ''  
                                          , @b_success OUTPUT  
                                          , @n_err OUTPUT  
                                          , @c_errmsg OUTPUT  
                       
                  IF @b_success <> 1  
                  BEGIN  
                     SET @n_continue = 3  
                     SET @n_err = 68001  
                     SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0)) +   
                                     ': Insert into TRANSMITLOG3 Failed. (isp_ITF_ntrCartonTrack) ( SQLSvr MESSAGE = ' +   
                                     ISNULL(LTRIM(RTRIM(@c_errmsg)),'') + ' ) '  
                     GOTO QUIT  
                  END   
               END -- IF @c_TargetTable = 'TRANSMITLOG3'  


               IF @c_TargetTable = 'TRANSMITLOG2'   
               BEGIN  
                  EXEC ispGenTransmitLog2 @c_Tablename, @c_OrderKey, @n_RowRef, @c_StorerKey, ''  
                                          , @b_success OUTPUT  
                                          , @n_err OUTPUT  
                                          , @c_errmsg OUTPUT  
                       
                  IF @b_success <> 1  
                  BEGIN  
                     SET @n_continue = 3  
                     SET @n_err = 68001  
                     SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0)) +   
                                     ': Insert into TRANSMITLOG2 Failed. (isp_ITF_ntrCartonTrack) ( SQLSvr MESSAGE = ' +   
                                     ISNULL(LTRIM(RTRIM(@c_errmsg)),'') + ' ) '  
                     GOTO QUIT  
                  END   
               END -- IF @c_TargetTable = 'TRANSMITLOG2'  
             
            END
  
            Get_Next_Config:
            
            FETCH NEXT FROM Cur_ITFTriggerConfig_Order INTO @c_ConfigKey, @c_ConfigFacility, @c_Tablename, @c_RecordType, @c_RecordStatus  
                                                            , @c_sValue, @c_TargetTable, @c_StoredProc, @c_UpdatedColumns   
         END -- WHILE @@FETCH_STATUS <> -1  
         CLOSE Cur_ITFTriggerConfig_Order  
         DEALLOCATE Cur_ITFTriggerConfig_Order  
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
      EXECUTE dbo.nsp_logerror @n_err, @c_errmsg, 'isp_ITF_ntrCartonTrack'  
  
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