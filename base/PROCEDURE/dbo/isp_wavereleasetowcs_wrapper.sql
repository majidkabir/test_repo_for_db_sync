SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: isp_WaveReleaseToWCS_Wrapper                       */  
/* Creation Date: 15-Nov-2011                                           */  
/* Copyright: IDS                                                       */  
/* Written by: YTWan                                                    */  
/*                                                                      */  
/* Purpose: SOS#230381 - Wave Release Task To WCS                       */  
/*          Storerconfig WaveReleaseToWCS_SP={SPName} to enable release */
/*          Wave to WCS option                                          */
/*                                                                      */  
/* Called By: Wave (Call ispWAVRL01)                                    */  
/*                                                                      */  
/* PVCS Version: 1.1                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author  Ver   Purposes                                  */  
/* 2024-01-19   Wan01   1.1   UWP-13590-WMS to send the Order Include   */
/*                            message to WCS upon Wave release          */
/************************************************************************/   
CREATE   PROCEDURE [dbo].[isp_WaveReleaseToWCS_Wrapper]  
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
   DECLARE @n_continue           INT
         , @n_Count              INT
         , @c_SPCode             NVARCHAR(30)                                       --(Wan01)
         , @c_Facility           NVARCHAR(5)    = ''                                --(Wan01)
         , @c_StorerKey          NVARCHAR(15)
         , @c_OrderStatus        NVARCHAR(10)
         , @c_SQL                NVARCHAR(MAX)
         , @c_CfgWavRLWCSOption5 NVARCHAR(4000) = ''                                --(Wan01)
         , @c_ReleaseOpenOrder   NVARCHAR(10)   = 'N'                               --(Wan01)
   SET @n_err        = 0
   SET @b_success    = 1
   SET @c_errmsg     = ''
   SET @n_continue   = 1
   SET @n_Count      = 0
   SET @c_SPCode     = ''
   SET @c_StorerKey  = ''
   SET @c_OrderStatus= ''
   SET @c_SQL        = ''
   SELECT TOP 1                                                                     --(Wan01) - START
           @c_Facility  = o.Facility
         , @c_Storerkey = o.StorerKey
         , @n_Count = 1
         , @c_OrderStatus = o.[Status]
   FROM dbo.WAVEDETAIL AS w (NOLOCK)
   JOIN dbo.ORDERS AS o (NOLOCK) ON o.OrderKey = w.OrderKey
   WHERE w.Wavekey = @c_Wavekey
   ORDER BY o.[Status] DESC
   --SELECT @n_Count = COUNT(1)
   --      ,@c_OrderStatus = ISNULL(MAX(RTRIM(ORDERS.Status)),'0')
   --FROM WAVEDETAIL WITH (NOLOCK)
   --JOIN ORDERS WITH (NOLOCK) ON (WAVEDETAIL.Orderkey = ORDERS.Orderkey)
   --WHERE WAVEDETAIL.Wavekey = @c_WaveKey  
   IF @n_Count = 0 
   BEGIN
       SET @n_continue = 3  
       SET @n_Err = 31211 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
       SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) 
                     + ': Wave: ' + RTRIM(@c_WaveKey) + ' does not have any orders. (isp_WaveReleaseToWCS_Wrapper)'  
       GOTO QUIT_SP
   END
   SELECT @c_SPCode = fsgr.Authority
         ,@c_CfgWavRLWCSOption5  = fsgr.ConfigOption5
   FROM dbo.fnc_SelectGetRight(@c_Facility, @c_Storerkey, '', 'WaveReleaseToWCS_SP') AS fsgr
   IF @c_SPCode = '0' SET @c_SPCode = ''
   IF @c_SPCode NOT IN ('')
   BEGIN
      IF @c_CfgWavRLWCSOption5 <> ''
      BEGIN
         SELECT @c_ReleaseOpenOrder = dbo.fnc_GetParamValueFromString('@c_ReleaseOpenOrder',@c_CfgWavRLWCSOption5,@c_ReleaseOpenOrder)
      END   
      IF @c_ReleaseOpenOrder = 'N'
      BEGIN
         IF @c_OrderStatus = 'CANC'   
         BEGIN
             SET @n_continue = 3  
             SET @n_Err = 31212 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
             SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) 
                           + ': Orders in Wave: ' + RTRIM(@c_WaveKey) + ' has been cancelled. (isp_WaveReleaseToWCS_Wrapper)'  
             GOTO QUIT_SP
         END
         IF @c_OrderStatus < '1'   
         BEGIN
             SET @n_continue = 3  
             SET @n_Err = 31212 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
             SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) 
                           + ': Wave: ' + RTRIM(@c_WaveKey) + ' has not allocated yet. (isp_WaveReleaseToWCS_Wrapper)'  
             GOTO QUIT_SP
         END
      END
      --SELECT @c_Storerkey = MAX(ORDERS.Storerkey)
      --FROM WAVEDETAIL WITH (NOLOCK)
      --JOIN ORDERS WITH (NOLOCK) ON (WAVEDETAIL.Orderkey = ORDERS.Orderkey)
      --WHERE WAVEDETAIL.Wavekey = @c_WaveKey    
      --SELECT @c_SPCode = sVALUE 
      --FROM   StorerConfig WITH (NOLOCK) 
      --WHERE  StorerKey = @c_StorerKey
      --AND    ConfigKey = 'WaveReleaseToWCS_SP'                                       
   END                                                                              --(Wan01) - END                                                                   
   IF ISNULL(RTRIM(@c_SPCode),'') = ''
   BEGIN       
       SET @n_continue = 3  
       SET @n_Err = 31213 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
       SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) 
                     + ': Please Setup Stored Procedure Name into Storer Configuration(WaveReleaseToWCS_SP) for '
                     + RTRIM(@c_StorerKey)+ '. (isp_WaveReleaseToWCS_Wrapper)'  
       GOTO QUIT_SP
   END
   IF NOT EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@c_SPCode) AND type = 'P')
   BEGIN
       SET @n_continue = 3  
       SET @n_Err = 31214
       SELECT @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err)  
                        + ': Storerconfig WaveReleaseToWCS_SP - Stored Proc name invalid ('+RTRIM(ISNULL(@c_SPCode,''))
                        + '). (isp_WaveReleaseToWCS_Wrapper)'  
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
       EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'isp_WaveReleaseToWCS_Wrapper'  
       --RAISERROR @n_Err @c_ErrMsg
   END   
END

GO