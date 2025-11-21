SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/
/* Store procedure: lsp_CBOLDelete_Wrapper                                 */
/* Creation Date: 17-Jul-2024                                              */
/* Copyright : Maersk Logistics                                            */
/* Written by: Shong                                                       */
/*                                                                         */
/* Purpose: UWP-21211 - Analysis: CBOL Migration from Exceed to MWMS V2    */
/*                                                                         */
/* Called By: MWMS Java                                                    */
/*                                                                         */
/* Version: 8.0                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date        Author   Ver   Purposes                                     */
/***************************************************************************/
CREATE   PROCEDURE [WM].[lsp_CBOLDelete_Wrapper] 
	   @n_Cbolkey                 BIGINT = 0
    , @b_Success                 INT            = 1  OUTPUT
    , @n_Err                     INT            = 0  OUTPUT
    , @c_ErrMsg                  NVARCHAR(250)  = '' OUTPUT
    , @n_WarningNo               INT            = 0  OUTPUT
    , @c_ProceedWithWarning      CHAR(1)        = 'N'
    , @c_UserName                NVARCHAR(128)  = ''
    , @n_ErrGroupKey             INT            = 0  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue                 INT = 1
         , @n_StartTCnt                INT = @@TRANCOUNT
         , @c_TableName                NVARCHAR(50)   = 'MBOL'
         , @c_SourceType               NVARCHAR(50)   = 'lsp_CBOLDelete_Wrapper'
         , @c_Refkey1                  NVARCHAR(20)   = ''                   
         , @c_Refkey2                  NVARCHAR(20)   = ''                   
         , @c_Refkey3                  NVARCHAR(20)   = ''                   
         , @c_WriteType                NVARCHAR(50)   = ''                   
         , @n_LogWarningNo             INT            = 0      
         , @n_LogErrNo                 INT            = ''                   
         , @c_LogErrMsg                NVARCHAR(255)  = ''            
         , @CUR_ERRLIST                CURSOR 
         , @c_MbolKey                  NVARCHAR(10)   = ''
         
 
   DECLARE  @t_WMSErrorList   TABLE                                  
         (  RowID             INT            IDENTITY(1,1) 
         ,  TableName         NVARCHAR(50)   NOT NULL DEFAULT('')  
         ,  SourceType        NVARCHAR(50)   NOT NULL DEFAULT('')
         ,  Refkey1           NVARCHAR(20)   NOT NULL DEFAULT('')
         ,  Refkey2           NVARCHAR(20)   NOT NULL DEFAULT('')
         ,  Refkey3           NVARCHAR(20)   NOT NULL DEFAULT('')
         ,  WriteType         NVARCHAR(50)   NOT NULL DEFAULT('')
         ,  LogWarningNo      INT            NOT NULL DEFAULT(0)
         ,  ErrCode           INT            NOT NULL DEFAULT(0)
         ,  Errmsg            NVARCHAR(255)  NOT NULL DEFAULT('')  
         )
   
   -- Switching SQL User ID from WMCOnnect to User Login ID
   SET  @n_ErrGroupKey = 0
   SET @n_Err = 0
   IF SUSER_SNAME() <> @c_UserName      
   BEGIN
      EXEC [WM].[lsp_SetUser] @c_UserName = @c_UserName OUTPUT, @n_Err = @n_Err OUTPUT, @c_ErrMsg = @c_ErrMsg OUTPUT

      IF @n_Err <> 0
      BEGIN
         GOTO EXIT_SP
      END

      EXECUTE AS LOGIN = @c_UserName
   END                                   

   DECLARE
           @c_Facility                 NVARCHAR(5)=''
         , @c_Status                   NVARCHAR(10)=''
         , @c_CBOLReference            NVARCHAR(30)=''
         , @c_StorerKey                NVARCHAR(15)=''
         , @c_GenCBOLRef               NVARCHAR(30)=''
         , @c_SUSR1                    NVARCHAR(30)=''
         , @c_NSqlValue                NVARCHAR(30)=''
         , @c_PRONumber                NVARCHAR(30)=''
         , @c_SealNo                   NVARCHAR(8)='' 
         , @c_VehicleContainer         NVARCHAR(30)=''
         , @c_UserDefine01             NVARCHAR(20)=''
         , @c_CtnType1                 NVARCHAR(30)=''
         , @c_CountedBy                NVARCHAR(10)=''
         , @d_PickupDate               DATETIME
         , @d_DepartureDate            DATETIME
         , @c_RoutingCIDNo             NVARCHAR(30)='' 
         , @c_Carrierkey               NVARCHAR(15)=''
         , @c_SCAC                     NVARCHAR(10)=''

   IF EXISTS(SELECT 1 FROM CBOL AS CB (NOLOCK)
             WHERE CBOLKey = @n_CBOLKey 
             AND CB.Status='9')
   BEGIN
      SET @n_Continue = 3
      SET @n_err = 557890
      SET @c_ErrMsg  = 'NSQL' + CONVERT(CHAR(6), @n_err)
                     + 'Not Allow to Delete for Shipped CBOL! (lsp_CBOLDelete_Wrapper)'      
      
   END
		
   BEGIN TRY     
      DECLARE CUR_MBOL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
      SELECT MBOLKey 
      FROM dbo.MBOL WITH (NOLOCK) 
      WHERE CBOLKey = @n_Cbolkey

      OPEN CUR_MBOL
      
      FETCH NEXT FROM CUR_MBOL INTO @c_MbolKey
      
      WHILE @@FETCH_STATUS = 0
      BEGIN

         EXEC [WM].[lsp_CBOLRemoveMBOL_Wrapper] 
	         @c_MbolKey             = @c_MbolKey                
	       , @n_Cbolkey             = @n_Cbolkey                
          , @b_Success             = @b_Success            OUTPUT
          , @n_Err                 = @n_Err                OUTPUT
          , @c_ErrMsg              = @c_ErrMsg             OUTPUT
          , @n_WarningNo           = @n_WarningNo          OUTPUT
          , @c_ProceedWithWarning  = @c_ProceedWithWarning 
          , @c_UserName            = @c_UserName           
          , @n_ErrGroupKey         = @n_ErrGroupKey        OUTPUT
      
          IF @n_Err <> 0 
          BEGIN
             SET @n_Continue = 3
          END
          FETCH NEXT FROM CUR_MBOL INTO @c_MbolKey
      END
      
      CLOSE CUR_MBOL
      DEALLOCATE CUR_MBOL
	   UPDATE MBOL WITH (ROWLOCK)
	      SET CBOLKey = 0, 
	            CBOLLineNumber='',
               BookingReference = CASE WHEN BookingReference = @c_RoutingCIDNo AND @c_NSqlValue = '1' THEN '' ELSE BookingReference END,
               PlaceOfDelivery=CASE WHEN PlaceOfDelivery = @c_CBOLReference AND @c_NSqlValue = '1' THEN '' ELSE PlaceOfDelivery END, 
	            trafficcop = NULL
	   WHERE CBOLKey = @n_Cbolkey
      AND MBOL.MBOLKey = @c_MbolKey 
	
      IF NOT EXISTS(SELECT 1 FROM MBOL WITH (NOLOCK) 
                    WHERE CBOLKey = @n_Cbolkey)
      BEGIN
          DELETE dbo.CBOL
          WHERE CBOLKey = @n_Cbolkey
      END
      ELSE 
      BEGIN
         SET @n_Continue = 3
         SET @n_err = 557890
         SET @c_ErrMsg  = 'NSQL' + CONVERT(CHAR(6), @n_err)
                        + 'Can not delete CBOL, still found MBOL under this CBOL! (lsp_CBOLDelete_Wrapper)'            
      END
   END TRY 
   BEGIN CATCH
      IF (XACT_STATE()) = -1
      BEGIN
         ROLLBACK TRAN
      END

      WHILE @@TRANCOUNT < @n_StartTCNT
      BEGIN
         BEGIN TRAN
      END

      SET @n_Continue = 3
      SET @n_err = 557890
      SET @c_ErrMsg = ERROR_MESSAGE()
      SET @c_ErrMsg  = 'NSQL' + CONVERT(CHAR(6), @n_err)
                     + 'Updating MBOL Fail! (' + @c_ErrMsg + ')'
   END CATCH

   IF @b_success = 0 OR @n_Err <> 0
   BEGIN
      INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)       
      VALUES (@c_TableName, @c_SourceType, @c_MbolKey, CAST(@n_Cbolkey AS VARCHAR(10)), '', 'ERROR', 0, @n_err, @c_errmsg) 
            
      SET @n_Continue = 3
      GOTO EXIT_SP
   END



   IF @n_Continue = 3
   BEGIN
      GOTO EXIT_SP
   END

 
   EXIT_SP:
   
   IF (XACT_STATE()) = -1               
   BEGIN
      SET @n_continue = 3
      ROLLBACK TRAN
   END                                  
    
   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF  @n_StartTCnt = 1 AND @@TRANCOUNT > @n_StartTCnt              
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_CBOLDelete_Wrapper '
      SET @n_WarningNo = 0
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt                              
      BEGIN
         COMMIT TRAN
      END
   END
   

   SET @CUR_ERRLIST = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT   twl.TableName         
         ,  twl.SourceType        
         ,  twl.Refkey1           
         ,  twl.Refkey2           
         ,  twl.Refkey3           
         ,  twl.WriteType         
         ,  twl.LogWarningNo      
         ,  twl.ErrCode           
         ,  twl.Errmsg               
   FROM @t_WMSErrorList AS twl
   ORDER BY twl.RowID
   
   OPEN @CUR_ERRLIST
   
   FETCH NEXT FROM @CUR_ERRLIST INTO   @c_TableName         
                                     , @c_SourceType        
                                     , @c_Refkey1           
                                     , @c_Refkey2           
                                     , @c_Refkey3           
                                     , @c_WriteType         
                                     , @n_LogWarningNo      
                                     , @n_LogErrNo           
                                     , @c_LogErrMsg           
   
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      EXEC [WM].[lsp_WriteError_List] 
         @i_iErrGroupKey= @n_ErrGroupKey OUTPUT 
      ,  @c_TableName   = @c_TableName
      ,  @c_SourceType  = @c_SourceType
      ,  @c_Refkey1     = @c_Refkey1
      ,  @c_Refkey2     = @c_Refkey2
      ,  @c_Refkey3     = @c_Refkey3
      ,  @n_LogWarningNo= @n_LogWarningNo
      ,  @c_WriteType   = @c_WriteType
      ,  @n_err2        = @n_LogErrNo 
      ,  @c_errmsg2     = @c_LogErrMsg 
      ,  @b_Success     = @b_Success    
      ,  @n_err         = @n_err        
      ,  @c_errmsg      = @c_errmsg         
     
      FETCH NEXT FROM @CUR_ERRLIST INTO   @c_TableName         
                                        , @c_SourceType        
                                        , @c_Refkey1           
                                        , @c_Refkey2           
                                        , @c_Refkey3           
                                        , @c_WriteType         
                                        , @n_LogWarningNo      
                                        , @n_LogErrNo           
                                        , @c_LogErrmsg     
   END
   CLOSE @CUR_ERRLIST
   DEALLOCATE @CUR_ERRLIST
   
   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END
   
   REVERT
END -- End Procedure

GO