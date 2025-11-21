SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: isp_LoadReleaseToProcess_Wrapper                   */  
/* Creation Date: 15-SEP-2021                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-17958 - [CN] MAST VS Add New RCM & SP for Auto-Sorting  */ 
/*          Machines Trigger                                            */
/*                                                                      */
/* Usage:   Storerconfig LoadReleaseToProcess_SP = ispLPRLPRO?? to      */
/*          enable release Load to process option                       */
/*                                                                      */
/* Called By: ue_releaseloadtoprocess                                   */
/*            from nep_n_cst_loadplan & nep_w_build_loadplan            */
/*                                                                      */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/************************************************************************/
CREATE PROCEDURE [dbo].[isp_LoadReleaseToProcess_Wrapper]  
   @c_Loadkey    NVARCHAR(MAX),   --Loadkeys delimited by comma   
   @c_CallFrom   NVARCHAR(50),    --BuildLoad / ManualLoad
   @b_Success    INT      OUTPUT,
   @n_Err        INT      OUTPUT, 
   @c_ErrMsg     NVARCHAR(250) OUTPUT
AS  
BEGIN  
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   DECLARE @n_continue      INT
         , @n_Count         INT
         , @c_SPCode        NVARCHAR(50)
         , @c_StorerKey     NVARCHAR(15)
         , @c_OrderStatus   NVARCHAR(10)
         , @c_SQL           NVARCHAR(MAX)
         , @c_GetLoadkey    NVARCHAR(10)

   SET @n_err        = 0
   SET @b_success    = 1
   SET @c_errmsg     = ''

   SET @n_continue   = 1
   SET @n_Count      = 0
   SET @c_SPCode     = ''
   SET @c_StorerKey  = ''
   SET @c_OrderStatus= ''
   SET @c_SQL        = ''
   SET @c_GetLoadkey = ''

   IF @n_continue IN (1,2)
   BEGIN
      DECLARE CUR_LOAD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT FDS.ColValue
      FROM dbo.fnc_DelimSplit(',', @c_Loadkey) FDS
      
      OPEN CUR_LOAD
      
      FETCH NEXT FROM CUR_LOAD INTO @c_GetLoadkey
      
      WHILE @@FETCH_STATUS <> -1 AND @n_continue IN (1,2)
      BEGIN
         SELECT @n_Count = COUNT(1)
               ,@c_OrderStatus = ISNULL(MAX(RTRIM(ORDERS.Status)),'0')
         FROM LOADPLANDETAIL WITH (NOLOCK)
         JOIN ORDERS WITH (NOLOCK) ON (LOADPLANDETAIL.Orderkey = ORDERS.Orderkey)
         WHERE LOADPLANDETAIL.LoadKey = @c_GetLoadkey  
         
         IF @n_Count = 0 
         BEGIN
            SET @n_continue = 3  
            SET @n_Err = 31211 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) 
                          + ': Load: ' + RTRIM(@c_GetLoadkey) + ' does not have any orders. (isp_LoadReleaseToProcess_Wrapper)'  
            GOTO QUIT_SP
         END
         
         IF @c_OrderStatus = 'CANC'   
         BEGIN
            SET @n_continue = 3  
            SET @n_Err = 31212 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) 
                          + ': Orders in Load: ' + RTRIM(@c_GetLoadkey) + ' has been cancelled. (isp_LoadReleaseToProcess_Wrapper)'  
            GOTO QUIT_SP
         END
         
         IF @c_OrderStatus < '1'   
         BEGIN
            SET @n_continue = 3  
            SET @n_Err = 31212 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) 
                          + ': Load: ' + RTRIM(@c_GetLoadkey) + ' has not allocated yet. (isp_LoadReleaseToProcess_Wrapper)'  
            GOTO QUIT_SP
         END
         
         SELECT @c_Storerkey = MAX(ORDERS.Storerkey)
         FROM LOADPLANDETAIL WITH (NOLOCK)
         JOIN ORDERS WITH (NOLOCK) ON (LOADPLANDETAIL.Orderkey = ORDERS.Orderkey)
         WHERE LOADPLANDETAIL.LoadKey = @c_GetLoadkey    
         
         SELECT @c_SPCode = sVALUE 
         FROM   StorerConfig WITH (NOLOCK) 
         WHERE  StorerKey = @c_StorerKey
         AND    ConfigKey = 'LoadReleaseToProcess_SP'  
         
         IF ISNULL(RTRIM(@c_SPCode),'') = ''
         BEGIN       
            SET @n_continue = 3  
            SET @n_Err = 31213 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) 
                          + ': Please Setup Stored Procedure Name into Storer Configuration(LoadReleaseToProcess_SP) for '
                          + RTRIM(@c_StorerKey)+ '. (isp_LoadReleaseToProcess_Wrapper)'  
            GOTO QUIT_SP
         END
         
         IF NOT EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@c_SPCode) AND type = 'P')
         BEGIN
            SET @n_continue = 3  
            SET @n_Err = 31214
            SELECT @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err)  
                             + ': Storerconfig LoadReleaseToProcess_SP - Stored Proc name invalid ('+RTRIM(ISNULL(@c_SPCode,''))
                             + '). (isp_LoadReleaseToProcess_Wrapper)'  
            GOTO QUIT_SP
         END
         
         
         SET @c_SQL = 'EXEC ' + @c_SPCode + ' @c_GetLoadkey, @c_CallFrom, @b_Success OUTPUT, @n_Err OUTPUT,' +
                      ' @c_ErrMsg OUTPUT '
           
         EXEC sp_executesql @c_SQL, 
              N'@c_GetLoadkey NVARCHAR(10), @c_CallFrom NVARCHAR(50), @b_Success int OUTPUT, @n_Err int OUTPUT, @c_ErrMsg NVARCHAR(250) OUTPUT', 
              @c_GetLoadkey,
              @c_CallFrom,
              @b_Success OUTPUT,                      
              @n_Err OUTPUT, 
              @c_ErrMsg OUTPUT
                              
         IF @b_Success <> 1
         BEGIN
            SELECT @n_continue = 3  
            GOTO QUIT_SP
         END

         FETCH NEXT FROM CUR_LOAD INTO @c_GetLoadkey
      END
      CLOSE CUR_LOAD
      DEALLOCATE CUR_LOAD
   END
             
   QUIT_SP:
   IF CURSOR_STATUS('LOCAL', 'CUR_LOAD') IN (0 , 1)
   BEGIN
      CLOSE CUR_LOAD
      DEALLOCATE CUR_LOAD   
   END

   IF @n_continue = 3
   BEGIN
      SELECT @b_success = 0
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'isp_LoadReleaseToProcess_Wrapper'  
      --RAISERROR @n_Err @c_ErrMsg
   END   
END

GO