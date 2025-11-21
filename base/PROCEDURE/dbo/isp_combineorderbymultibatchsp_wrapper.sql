SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: isp_CombineOrderByMultiBatchSP_Wrapper              */  
/* Creation Date: 07-Aug-2020                                            */  
/* Copyright: LFL                                                        */  
/* Written by: WLChooi                                                   */  
/*                                                                       */  
/* Purpose: WMS-14579 - Combine Order By Multi Batch                     */  
/*          Storerconfig CombineOrderByMultiBatchSP={ispCBORDBTHxx}      */
/*          to call customize SP                                         */
/*                                                                       */  
/* Called By: Shipment Order                                             */  
/*                                                                       */  
/* GitLab Version: 1.0                                                   */  
/*                                                                       */  
/* Version: 5.4                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date         Author   Ver  Purposes                                   */  
/*************************************************************************/   
CREATE PROCEDURE [dbo].[isp_CombineOrderByMultiBatchSP_Wrapper]  
      @c_OrderList          NVARCHAR(MAX) 
   ,  @b_Success            INT OUTPUT    
   ,  @n_Err                INT OUTPUT
   ,  @c_Errmsg             NVARCHAR(255) OUTPUT
   ,  @n_Continue           INT OUTPUT
   ,  @c_FromOrderkeyList   NVARCHAR(MAX) OUTPUT
AS  
BEGIN  
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   DECLARE @c_SPCode            NVARCHAR(50)
         , @c_StorerKey         NVARCHAR(15)
         , @c_SQL               NVARCHAR(MAX)
         , @c_facility          NVARCHAR(5) 
         , @c_authority         NVARCHAR(10) 
         , @b_debug             INT = 0

         , @d_Trace_StartTime   DATETIME
         , @d_Trace_EndTime     DATETIME
         , @c_UserName          NVARCHAR(100)

         , @c_StorerkeyCount    INT = 0

   SET @n_err        = 0
   SET @b_Success    = 1
   SET @c_errmsg     = ''

   SET @n_Continue   = 1
   SET @c_SPCode     = ''
   SET @c_StorerKey  = ''
   SET @c_SQL        = ''

   SET @d_Trace_StartTime = GETDATE()

   SELECT @c_StorerkeyCount = COUNT(DISTINCT Storerkey)
   FROM ORDERS (NOLOCK)
   WHERE ORDERKEY IN (SELECT DISTINCT ColValue 
                      FROM fnc_DelimSplit(',',@c_OrderList))

   IF @c_StorerkeyCount > 1
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 61200
      SELECT @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err)  
                       + ': Not allow to combine orderkey from multiple storerkey (isp_CombineOrderByMultiBatchSP_Wrapper)' 
      GOTO QUIT_SP
   END

   SELECT @c_StorerKey = Storerkey
   FROM ORDERS (NOLOCK)
   WHERE ORDERKEY IN (SELECT DISTINCT ColValue 
                      FROM fnc_DelimSplit(',',@c_OrderList))
   
   SELECT @c_SPCode = sVALUE 
   FROM   StorerConfig WITH (NOLOCK) 
   WHERE  StorerKey = @c_StorerKey
   AND    ConfigKey = 'CombineOrderByMultiBatchSP'  

   --Storerconfig Not Setup
   IF ISNULL(@c_SPCode,'') = ''
   BEGIN
      SET @n_Continue = 2
      GOTO QUIT_SP
   END
   
   IF NOT EXISTS (SELECT 1 FROM dbo.sysobjects WITH (NOLOCK) WHERE name = RTRIM(@c_SPCode) AND type = 'P')
   BEGIN
       SET @n_Continue = 3  
       SET @n_Err = 61205
       SELECT @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err)  
                        + ': Storerconfig CombineOrderByMultiBatchSP - Stored Proc name invalid ('+RTRIM(ISNULL(@c_SPCode,''))
                        + '). (isp_CombineOrderByMultiBatchSP_Wrapper)'  
       GOTO QUIT_SP
   END
   
   SET @c_SQL = 'EXEC ' + @c_SPCode + ' @c_OrderList, @b_Success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT, @c_FromOrderkeyList OUTPUT'

   EXEC sp_executesql @c_SQL 
      ,  N'@c_OrderList NVARCHAR(MAX), @b_Success INT OUTPUT, @n_Err INT OUTPUT, @c_ErrMsg NVARCHAR(255) OUTPUT, @c_FromOrderkeyList NVARCHAR(MAX) OUTPUT' 
      ,  @c_OrderList
      ,  @b_Success OUTPUT   
      ,  @n_Err OUTPUT
      ,  @c_ErrMsg OUTPUT
      ,  @c_FromOrderkeyList OUTPUT
                        
   IF @b_Success <> 1
   BEGIN
       SELECT @n_Continue = 3  
       GOTO QUIT_SP
   END
     
QUIT_SP:
   SET @d_Trace_EndTime = GETDATE()
   SET @c_UserName = SUSER_SNAME()
   
   -- EXEC isp_InsertTraceInfo 
   --    @c_TraceCode = 'PostBuildLoad_SP',
   --    @c_TraceName = 'isp_CombineOrderByMultiBatchSP_Wrapper',
   --    @c_starttime = @d_Trace_StartTime,
   --    @c_endtime   = @d_Trace_EndTime,
   --    @c_step1     = '@c_UserName',
   --    @c_step2     = '@c_Loadkey',
   --    @c_step3     = '@c_StorerKey',
   --    @c_step4     = '@c_Facility',
   --    @c_step5     = '@c_SPCode',
   --    @c_col1      = @c_UserName, 
   --    @c_col2      = @c_Loadkey,
   --    @c_col3      = @c_StorerKey,
   --    @c_col4      = @c_Facility,
   --    @c_col5      = @c_SPCode,
   --    @b_Success   = 1,
   --    @n_Err       = 0,
   --    @c_ErrMsg    = '' 
   
   IF @n_Continue = 3
   BEGIN
       SELECT @b_Success = 0
       EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'isp_CombineOrderByMultiBatchSP_Wrapper'  
       RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END   
END

GO