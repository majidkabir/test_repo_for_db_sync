SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/*************************************************************************/  
/* Stored Procedure: lsp_OTM_TPEX_ITF_ORD_Wrapper                        */  
/* Creation Date: 22-OCT-2020                                            */  
/* Copyright: LFL                                                        */  
/* Written by: Wan                                                       */  
/*                                                                       */  
/* Purpose:                                                              */  
/*                                                                       */  
/* Called By:                                                            */  
/*                                                                       */  
/*                                                                       */  
/* Version: 1.1                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date        Author   Ver  Purposes                                    */ 
/* 22-OCT-2020 Wan      1.0   Created                                    */   
/* 15-Jan-2021 Wan01    1.1   Execute Login if @c_UserName<>SUSER_SNAME()*/      
/*************************************************************************/   
CREATE PROC [WM].[lsp_OTM_TPEX_ITF_ORD_Wrapper] (
  @c_Orderkeys          NVARCHAR(2000)       -- List of Orderkey with | seperator
, @b_Success            INT            = 1   OUTPUT
, @n_Err                INT            = 0   OUTPUT
, @c_ErrMsg             NVARCHAR(250)  = ''  OUTPUT
, @n_WarningNo          INT            = 0   OUTPUT
, @c_UserName           NVARCHAR(128)  =''
, @n_ErrGroupKey        INT            = 0   OUTPUT
) AS 
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue           INT = 1
         , @n_StartTCnt          INT = @@TRANCOUNT

         , @c_Facility           NVARCHAR(5)  = ''
         , @c_Storerkey          NVARCHAR(15) = ''
         , @c_Orderkey           NVARCHAR(10) = ''
         , @c_Status             NVARCHAR(10) = ''

         , @c_ITF_TableName      NVARCHAR(10)   = 'SORCMOTM'
         , @c_ITF_Transmitflag   NVARCHAR(10)   = '0'
         , @c_ITF_Resendflag     NVARCHAR(10)   = '1'

         , @c_TableName          NVARCHAR(50)   = 'ORDER'
         , @c_SourceType         NVARCHAR(50)   = 'lsp_OTM_TPEX_ITF_ORD_Wrapper'

         , @c_TPEX_INF_ORDERUPD  NVARCHAR(30)   = '0'
         , @c_WriteType          NVARCHAR(10)   = ''

         , @CUR_ITFCHK           CURSOR
         , @CUR_ITF              CURSOR

   --2020-11-20 - START
   SET @n_Err = 0 
   IF SUSER_SNAME() <> @c_UserName       --(Wan01) - START
   BEGIN
      EXEC [WM].[lsp_SetUser] @c_UserName = @c_UserName OUTPUT, @n_Err = @n_Err OUTPUT, @c_ErrMsg = @c_ErrMsg OUTPUT
    
      IF @n_Err <> 0 
      BEGIN
         GOTO EXIT_SP
      END
                
      EXECUTE AS LOGIN = @c_UserName        
   END                                   --(Wan01) - END
   --2020-11-20 - END

   BEGIN TRY
   	
      DECLARE @tORDERS TABLE (
              Orderkey  NVARCHAR(10)   NOT NULL PRIMARY KEY
            , Facility  NVARCHAR(5)    NOT NULL DEFAULT('')
            , Storerkey NVARCHAR(15)   NOT NULL DEFAULT('')
            , [Status]  NVARCHAR(10)   NOT NULL DEFAULT('')
            )

      INSERT INTO @tORDERS ( Orderkey, Facility, Storerkey, [Status] )
      SELECT DISTINCT Orderkey =  SS.[Value]
            , OH.Facility
            , OH.Storerkey
            , OH.[Status]
      FROM STRING_SPLIT ( @c_Orderkeys, '|') SS 
      JOIN ORDERS OH WITH (NOLOCK) ON SS.[Value] = OH.Orderkey 
      ORDER BY 1        

      IF NOT EXISTS  (  SELECT 1 
                        FROM @tORDERS
                     )
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 558751
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + '. No Order found for interface.'
                       + ' (lsp_OTM_TPEX_ITF_ORD_Wrapper)'

         EXEC [WM].[lsp_WriteError_List] 
               @i_iErrGroupKey= @n_ErrGroupKey OUTPUT
            ,  @c_TableName   = @c_TableName
            ,  @c_SourceType  = @c_SourceType
            ,  @c_Refkey1     = @c_Orderkeys
            ,  @c_Refkey2     = ''
            ,  @c_Refkey3     = ''
            ,  @c_WriteType   = 'ERROR'
            ,  @n_err2        = @n_err
            ,  @c_errmsg2     = @c_errmsg
            ,  @b_Success     = @b_Success   OUTPUT
            ,  @n_err         = @n_err       OUTPUT
            ,  @c_errmsg      = @c_errmsg    OUTPUT

         GOTO EXIT_SP
      END

      SET @CUR_ITFCHK = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
      SELECT Orderkey
            ,Facility
            ,Storerkey
      FROM @tORDERS T

      OPEN @CUR_ITFCHK

      FETCH NEXT FROM @CUR_ITFCHK INTO @c_Orderkey, @c_Facility, @c_Storerkey

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         SELECT @c_TPEX_INF_ORDERUPD  = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'TPEX_INF_ORDERUPD')

         IF @c_TPEX_INF_ORDERUPD = '0'
         BEGIN
            SET @n_Continue = 3
            SET @n_Err = 558752
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + '. Order''s Storer does not setup for TPEX interface.'
                          + ' (lsp_OTM_TPEX_ITF_ORD_Wrapper)'

            EXEC [WM].[lsp_WriteError_List] 
                  @i_iErrGroupKey= @n_ErrGroupKey OUTPUT
               ,  @c_TableName   = @c_TableName
               ,  @c_SourceType  = @c_SourceType
               ,  @c_Refkey1     = @c_Orderkey
               ,  @c_Refkey2     = ''
               ,  @c_Refkey3     = ''
               ,  @c_WriteType   = 'ERROR'
               ,  @n_err2        = @n_err
               ,  @c_errmsg2     = @c_errmsg
               ,  @b_Success     = @b_Success   OUTPUT
               ,  @n_err         = @n_err       OUTPUT
               ,  @c_errmsg      = @c_errmsg    OUTPUT

            DELETE @tORDERS WHERE Orderkey  = @c_Orderkey
         END

         FETCH NEXT FROM @CUR_ITFCHK INTO @c_Orderkey, @c_Facility, @c_Storerkey
      END
      CLOSE @CUR_ITFCHK
      DEALLOCATE @CUR_ITFCHK
   
      SET @CUR_ITF = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
      SELECT Orderkey
            ,Storerkey
            ,[Status]
      FROM @tORDERS T

      OPEN @CUR_ITF

      FETCH NEXT FROM @CUR_ITF INTO @c_Orderkey, @c_Storerkey, @c_Status

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         BEGIN TRAN
         SET @n_Continue = 1
         SET @n_Err = 0
         SET @c_ErrMsg = ''
         BEGIN TRY
            EXEC isp_OTM_TPEX_Interface
         	     @c_tablename    = @c_ITF_TableName
	            , @c_key1         = @c_Orderkey
	            , @c_key2         = @c_Status
	            , @c_key3         = @c_Storerkey
	            , @c_transmitflag = @c_ITF_transmitflag
	            , @c_transmitbatch= ''
	            , @c_resendflag   = @c_ITF_Resendflag
	            , @b_success      = @b_success   OUTPUT
	            , @n_err          = @n_err       OUTPUT 
	            , @c_errmsg       = @c_errmsg    OUTPUT
         END TRY
         BEGIN CATCH
            SET @b_success = 0

            IF (XACT_STATE()) = -1     
            BEGIN
               IF @@TRANCOUNT > 0 
               BEGIN
                  ROLLBACK TRAN
               END
            END                        
         END CATCH

         IF @b_success = 0
         BEGIN
            SET @n_Continue = 3
            SET @n_Err = 558753
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + '. Error Executing isp_OTM_TPEX_Interface.'
                           + ' (lsp_OTM_TPEX_ITF_ORD_Wrapper) ' 
                           + CASE WHEN @c_ErrMsg = '' THEN ''
                                 ELSE ' ( ' + @c_errmsg + ' ) '
                                 END
         END

         IF @n_Continue = 3 
         BEGIN 
            SET @c_WriteType = 'ERROR'
            IF @@TRANCOUNT > 0 
            BEGIN
               ROLLBACK TRAN
            END
         END
         ELSE
         BEGIN
            SET @c_WriteType = 'MESSAGE'
            SET @c_errmsg = 'Send TPEX Update Successfully.'

            WHILE @@TRANCOUNT > 0 
            BEGIN
               COMMIT TRAN
            END
         END 

         EXEC [WM].[lsp_WriteError_List] 
               @i_iErrGroupKey= @n_ErrGroupKey OUTPUT
            ,  @c_TableName   = @c_TableName
            ,  @c_SourceType  = @c_SourceType
            ,  @c_Refkey1     = @c_Orderkey
            ,  @c_Refkey2     = ''
            ,  @c_Refkey3     = ''
            ,  @c_WriteType   = @c_WriteType
            ,  @n_err2        = @n_err
            ,  @c_errmsg2     = @c_errmsg
            ,  @b_Success     = @b_Success   OUTPUT
            ,  @n_err         = @n_err       OUTPUT
            ,  @c_errmsg      = @c_errmsg    OUTPUT
 

         FETCH NEXT FROM @CUR_ITF INTO @c_Orderkey, @c_Storerkey, @c_Status
      END
      CLOSE @CUR_ITF
      DEALLOCATE @CUR_ITF
   END TRY
   BEGIN CATCH
      SET @n_continue = 3
      SET @c_ErrMsg = 'OTM TPEX Order Interface fail. (lsp_OTM_TPEX_ITF_ORD_Wrapper) ( SQLSvr MESSAGE=' + ERROR_MESSAGE() + ' ) '
      GOTO EXIT_SP
   END CATCH
   
   EXIT_SP:
   
   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_OTM_TPEX_ITF_ORD_Wrapper'
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
      
   REVERT
END -- Procedure

GO