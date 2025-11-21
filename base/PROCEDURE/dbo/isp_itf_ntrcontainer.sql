SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Store Procedure:  isp_ITF_ntrContainer                               */  
/* Creation Date: 26-Feb-2019                                           */  
/* Copyright: LF                                                        */  
/* Written by: MCTang                                                   */  
/*                                                                      */  
/* Purpose:  Handling trigger points for Container's module.            */  
/*           Including Container Header trigger points for Add&Update   */  
/*                                                                      */  
/* Output Parameters:  @b_Success                                       */  
/*                     @n_Err                                           */  
/*                     @c_ErrMsg                                        */  
/*                                                                      */  
/* Return Status:  @b_Success = 0 or 1                                  */  
/*                                                                      */  
/* Usage:  StorerConfig & Trigger Points verification & update on       */  
/*         configuration table - ITFTriggerConfig.                      */  
/*                                                                      */  
/* Called By:  Trigger/Store Procedure.                                 */  
/*             - ntrContainerHeaderAdd                                  */  
/*             - ntrContainerHeaderUpdate                               */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/* Date         Author    Ver.  Purposes                                */  
/************************************************************************/  
  
CREATE PROC [dbo].[isp_ITF_ntrContainer]  
            @c_TriggerName          NVARCHAR(120)  
          , @c_SourceTable          NVARCHAR(60)  
          , @c_StorerKey            NVARCHAR(15)  
          , @c_ContainerKey         NVARCHAR(20)  
          , @c_ColumnsUpdated       VARCHAR(1000)                          
          , @b_Success              INT           OUTPUT  
          , @n_Err                  INT           OUTPUT  
          , @c_ErrMsg               NVARCHAR(250) OUTPUT  
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
         , @c_RecordType            NVARCHAR(10)  
         , @c_RecordStatus          NVARCHAR(10)  
         , @c_sValue                NVARCHAR(10)  
         , @c_TargetTable           NVARCHAR(60)  
         , @c_StoredProc            NVARCHAR(200)  
         , @c_ConfigFacility        NVARCHAR(5)
         , @c_UpdatedColumns        NVARCHAR(250)      
  
   DECLARE @c_Status                NVARCHAR(10)  
         , @c_FinalizeFlag          NVARCHAR(1)   
  
   SET @n_StartTCnt = @@TRANCOUNT   
   SET @n_continue = 1   
   SET @b_success = 0   
   SET @n_Err = 0   
   SET @c_ErrMsg = ''                     
   /********************************************************/  
   /* Variables Declaration & Initialization - (End)       */  
   /********************************************************/  
  
   /*************************************************************************************/  
   /* Std - Verify Parameter variables, no values found, return to core program (Start) */  
   /*************************************************************************************/  
   IF (ISNULL(RTRIM(@c_TriggerName),'') = '') OR   
      (ISNULL(RTRIM(@c_SourceTable),'') = '') OR         
      (ISNULL(RTRIM(@c_ContainerKey),'') = '')  
   BEGIN  
      RETURN  
   END  
  
   IF (ISNULL(RTRIM(@c_TriggerName),'') <> 'ntrContainerHeaderUpdate')  
   BEGIN  
      IF (ISNULL(RTRIM(@c_TriggerName),'') <> 'ntrContainerHeaderAdd')  
      BEGIN  
         RETURN  
      END  
   END  
  
   IF (ISNULL(RTRIM(@c_SourceTable),'') <> 'CONTAINER')  
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
      SELECT @c_Status = ISNULL(RTRIM(Status),'')  
      FROM   CONTAINER WITH (NOLOCK)   
      WHERE  ContainerKey = @c_ContainerKey  
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
         DECLARE Cur_ITFTriggerConfig CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
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
  
         OPEN Cur_ITFTriggerConfig  
         FETCH NEXT FROM Cur_ITFTriggerConfig INTO @c_ConfigKey, @c_ConfigFacility, @c_Tablename, @c_RecordType, @c_RecordStatus  
                                                         , @c_sValue, @c_TargetTable, @c_StoredProc, @c_UpdatedColumns   
  
         WHILE @@FETCH_STATUS <> -1  
         BEGIN 

            IF ISNULL(RTRIM(@c_UpdatedColumns), '') <> ''
            BEGIN
               --IF NOT EXISTS(SELECT 1 FROM                                                                            
               --              dbo.fnc_GetUpdatedColumns(@c_SourceTable, @b_ColumnsUpdated)                             
               --              WHERE COLUMN_NAME IN (                                                                   
               --                              SELECT ColValue                                                          
               --                              FROM dbo.fnc_DelimSplit(',', @c_UpdatedColumns)))                        

               IF NOT EXISTS(SELECT 1 FROM                                                                              
                              dbo.fnc_DelimSplit(',', @c_ColumnsUpdated)                                                
                              WHERE ColValue IN (SELECT ColValue FROM dbo.fnc_DelimSplit(',', @c_UpdatedColumns)))        
               BEGIN
                  --PRINT 'Not Exists, GET_NEXT_Record '
                  GOTO GET_NEXT_Record
               END 
            END
            ELSE
            BEGIN
               GOTO GET_NEXT_Record
            END
            
            SET @b_Success = 0
            
            IF ISNULL(RTRIM(@c_StoredProc),'') <> ''
            BEGIN
               SET @b_Success = 0 
               
               EXEC sys.sp_executesql @c_StoredProc, N'@c_ContainerKey NVARCHAR(20), @b_Success INT OUTPUT, @c_ErrNo INT OUTPUT, @c_ErrMsg NVARCHAR(215) OUTPUT',
                           @c_ContainerKey, 
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
               IF @c_TargetTable = 'TRANSMITLOG3'   
               BEGIN  
                  EXEC ispGenTransmitLog3 @c_Tablename, @c_ContainerKey, '', @c_StorerKey, ''  
                                          , @b_success OUTPUT  
                                          , @n_Err OUTPUT  
                                          , @c_ErrMsg OUTPUT  
                       
                  IF @b_success <> 1  
                  BEGIN  
                     SET @n_continue = 3  
                     SET @n_Err = 68001  
                     SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_Err,0)) +   
                                     ': Insert into TRANSMITLOG3 Failed. (isp_ITF_ntrContainer) ( SQLSvr MESSAGE = ' +   
                                     ISNULL(LTRIM(RTRIM(@c_ErrMsg)),'') + ' ) '  
                     GOTO QUIT  
                  END   
               END -- IF @c_TargetTable = 'TRANSMITLOG3'   

               IF @c_TargetTable = 'TRANSMITLOG2'   
               BEGIN  
                  EXEC ispGenTransmitLog2 @c_Tablename, @c_ContainerKey, '', @c_StorerKey, '' 
                                          , @b_success OUTPUT  
                                          , @n_Err OUTPUT  
                                          , @c_ErrMsg OUTPUT  
                       
                  IF @b_success <> 1  
                  BEGIN  
                     SET @n_continue = 3  
                     SET @n_Err = 68001  
                     SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_Err,0)) +   
                                     ': Insert into TRANSMITLOG2 Failed. (isp_ITF_ntrContainer) ( SQLSvr MESSAGE = ' +   
                                     ISNULL(LTRIM(RTRIM(@c_ErrMsg)),'') + ' ) '  
                     GOTO QUIT  
                  END   
               END -- IF @c_TargetTable = 'TRANSMITLOG2'               
            END
  
            GET_NEXT_Record:
            
            FETCH NEXT FROM Cur_ITFTriggerConfig INTO @c_ConfigKey, @c_ConfigFacility, @c_Tablename, @c_RecordType, @c_RecordStatus  
                                                            , @c_sValue, @c_TargetTable, @c_StoredProc, @c_UpdatedColumns   
         END -- WHILE @@FETCH_STATUS <> -1  
         CLOSE Cur_ITFTriggerConfig  
         DEALLOCATE Cur_ITFTriggerConfig  
      END -- IF EXISTS ( SELECT 1 FROM ITFTriggerConfig WITH (NOLOCK)   
   END -- IF @n_continue = 1 OR @n_continue = 2  

   /* Handle ITC.StorerKey='ALL' which not able to configure detail in ITFTriggerConfig */   
   /*
   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN 

      /********************************************/  
      /* OTMITF (START)                           */  
      /********************************************/ 
      IF EXISTS ( SELECT 1 FROM ITFTriggerConfig ITC WITH (NOLOCK)    
                  JOIN   StorerConfig STC WITH (NOLOCK)                                                          
                  ON    (STC.StorerKey   = @c_StorerKey AND STC.ConfigKey = 'OTMITF' AND STC.SValue = '1' AND STC.ConfigKey = ITC.ConfigKey)   
                  WHERE  ITC.StorerKey   = 'ALL'   
                  AND    ITC.SourceTable = @c_SourceTable  
                  AND    ITC.sValue      = '1' )  
      BEGIN
         IF ISNULL(RTRIM(@c_TriggerName),'') = 'ntrContainerHeaderUpdate'
         BEGIN
            --MC02 - S
            IF EXISTS(SELECT 1 FROM                                                                            
                      dbo.fnc_DelimSplit(',', @c_ColumnsUpdated)                                               
                      WHERE ColValue = 'Status' )                                                       
            BEGIN
               IF @c_Status = 'C'
               BEGIN
   	            IF EXISTS ( SELECT 1 FROM StorerConfig STC WITH (NOLOCK)        
   	                        WHERE STC.StorerKey = @c_Storerkey 
                              AND   STC.ConfigKey = 'XXXXXXXOTM'
   	                        AND   STC.SValue    = '1' )
                  BEGIN   
                     EXEC ispGenOTMLog 'XXXXXXXOTM', @c_ContainerKey, 'C', @c_StorerKey, ''  
                                       , @b_success   OUTPUT  
                                       , @n_Err       OUTPUT  
                                       , @c_ErrMsg    OUTPUT 

                     IF @b_success <> 1
                     BEGIN
                        SET @n_continue = 3
                        GOTO QUIT 
                     END
                  END
               END
            END
            --MC02 - E
         END -- IF (ISNULL(RTRIM(@c_TriggerName),'') = 'ntrOrderHeaderUpdate')  
      END -- IF EXISTS ( SELECT 1 FROM ITFTriggerConfig WITH (NOLOCK)    
      /********************************************/  
      /* OTMITF (End)                             */  
      /********************************************/
   END -- IF @n_continue = 1 OR @n_continue = 2 
   */

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
      EXECUTE dbo.nsp_logerror @n_Err, @c_ErrMsg, 'isp_ITF_ntrContainer'  
  
      RAISERROR (@c_ErrMsg, 16, 1) WITH SETERROR  
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