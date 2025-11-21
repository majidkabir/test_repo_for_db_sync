SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: isp_WaveGenLoadPlan_Wrapper                        */  
/* Creation Date: 02-Nov-2011                                           */  
/* Copyright: IDS                                                       */  
/* Written by: NJOW                                                     */  
/*                                                                      */  
/* Purpose: Wave Generate Load Plan                                     */  
/*                                                                      */  
/* Called By: Wave Plan (Call ispWAVLP01) Default isp_WaveGenLoadByCons */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/* 06-Jun-2013  Shong    1.1  Filter By Facility When Getting Storer    */
/*                            Config                                    */
/************************************************************************/  
CREATE PROCEDURE [dbo].[isp_WaveGenLoadPlan_Wrapper]  
   @c_WaveKey    NVARCHAR(10),  
   @b_Success    INT      OUTPUT,  
   @n_Err        INT      OUTPUT,  
   @c_ErrMsg     NVARCHAR(250) OUTPUT  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @n_continue      INT,  
           @c_StorerKey     NVARCHAR(15), 
           @c_Facility      NVARCHAR(5),  
           @c_SPCode        NVARCHAR(50),  
           @c_SQL           NVARCHAR(MAX)  
  
   SELECT @c_SPCode = '', @n_err=0, @b_success=1, @c_errmsg=''  
  
   SELECT TOP 1 
      @c_Storerkey = ORDERS.Storerkey, 
      @c_Facility  = ORDERS.Facility  
   FROM WAVEDETAIL (NOLOCK)  
   JOIN ORDERS (NOLOCK) ON (WAVEDETAIL.Orderkey = ORDERS.Orderkey) 
   WHERE WAVEDETAIL.Wavekey = @c_WaveKey  
  
   SET @c_SPCode = ''
   
   SELECT @c_SPCode = ISNULL(sVALUE,'')    
   FROM   StorerConfig WITH (NOLOCK)  
   WHERE  StorerKey = @c_StorerKey  
   AND    ConfigKey = 'WAVEGENLOADPLAN' 
   AND    Facility = @c_Facility   
   IF ISNULL(RTRIM(@c_SPCode),'') =''  
   BEGIN 
      SELECT @c_SPCode = ISNULL(sVALUE,'')  
      FROM   StorerConfig WITH (NOLOCK)  
      WHERE  StorerKey = @c_StorerKey  
      AND    ConfigKey = 'WAVEGENLOADPLAN' 
      AND   (Facility = '' OR Facility IS NULL)         
   END
   
  
   IF ISNULL(RTRIM(@c_SPCode),'') =''  
   BEGIN  
         SELECT @c_SPCode = 'isp_WaveGenLoadByCons'  
       /*  
       SELECT @n_continue = 3  
       SELECT @c_ErrMsg = CONVERT(CHAR(250), @n_Err),  
              @n_Err = 31011 -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
       SELECT @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) +  
              ': Please Setup Stored Procedure Name into Storer Configuration for '+RTRIM(@c_StorerKey)+' (isp_WaveGenLoadPlan_Wrapper)'  
       GOTO QUIT_SP  
       */  
   END  
  
   IF NOT EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@c_SPCode) AND type = 'P')  
   BEGIN  
       SELECT @n_continue = 3  
       SELECT @c_ErrMsg = CONVERT(CHAR(250), @n_Err),  
              @n_Err = 31012 -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
       SELECT @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) +  
              ': Storerconfig WAVEGENLOADPLAN - Stored Proc name invalid ('+RTRIM(ISNULL(@c_SPCode,''))+') (isp_WaveGenLoadPlan_Wrapper)'  
       GOTO QUIT_SP  
   END  
  
  
   SET @c_SQL = 'EXEC ' + @c_SPCode + ' @c_WaveKey, @b_Success OUTPUT, @n_Err OUTPUT,' +  
                ' @c_ErrMsg OUTPUT '  
  
   EXEC sp_executesql @c_SQL,  
        N'@c_WaveKey NVARCHAR(10), @b_Success int OUTPUT, @n_Err int OUTPUT, @c_ErrMsg NVARCHAR(250) OUTPUT',  
        @c_WaveKey,  
        @b_Success OUTPUT,  
        @n_Err OUTPUT,  
        @c_ErrMsg OUTPUT  
  
   IF @b_Success <> 1  
   BEGIN  
       SELECT @n_continue = 3  
       GOTO QUIT_SP  
   END  
  
   QUIT_SP:  
   IF @n_continue = 3  
   BEGIN  
       SELECT @b_success = 0  
       EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'isp_WaveGenLoadPlan_Wrapper'  
       RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
   END  
END    

GO