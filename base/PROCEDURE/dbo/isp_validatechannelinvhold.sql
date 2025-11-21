SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_ValidateChannelInvHold                              */
/* Creation Date: 26-JUL-2019                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-9995 [CN] NIKESDC_Exceed_Hold ASN for Channel           */
/*        :                                                             */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_ValidateChannelInvHold] 
           @c_HoldType           NVARCHAR(10)= ''
         , @c_Facility           NVARCHAR(5) = ''
         , @c_Storerkey          NVARCHAR(15)= ''
         , @c_Sku                NVARCHAR(20)= ''
         , @c_Channel            NVARCHAR(20)= ''
         , @c_C_Attribute01      NVARCHAR(30)= ''
         , @c_C_Attribute02      NVARCHAR(30)= ''
         , @c_C_Attribute03      NVARCHAR(30)= ''
         , @c_C_Attribute04      NVARCHAR(30)= ''
         , @c_C_Attribute05      NVARCHAR(30)= ''
         , @n_Channel_ID         BIGINT      = 0
         , @c_Hold               NVARCHAR(1) = '0'
         , @c_Remarks            NVARCHAR(255) = ''
         , @b_Success            INT            OUTPUT
         , @n_Err                INT            OUTPUT
         , @c_ErrMsg             NVARCHAR(255)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT   = @@TRANCOUNT
         , @n_Continue        INT   = 1

         , @n_Cnt             INT   = 0 
         , @c_SQL             NVARCHAR(1000) = ''
         , @c_SQLParms        NVARCHAR(1000) = ''

   SET @n_err      = 0
   SET @c_errmsg   = ''

   SET @c_HoldType      = ISNULL(@c_HoldType     ,'')   
   SET @c_Facility      = ISNULL(@c_Facility     ,'')
   SET @c_Storerkey     = ISNULL(@c_Storerkey    ,'')
   SET @c_Sku           = ISNULL(@c_Sku          ,'')
   SET @c_Channel       = ISNULL(@c_Channel      ,'')
   SET @c_C_Attribute01 = ISNULL(@c_C_Attribute01,'')
   SET @c_C_Attribute02 = ISNULL(@c_C_Attribute02,'')
   SET @c_C_Attribute03 = ISNULL(@c_C_Attribute03,'')
   SET @c_C_Attribute04 = ISNULL(@c_C_Attribute04,'')
   SET @c_C_Attribute05 = ISNULL(@c_C_Attribute05,'')
   SET @n_Channel_ID    = ISNULL(@n_Channel_ID,0)

   IF ( @c_Facility      = '' AND 
        @c_Storerkey     = '' AND 
        @c_Sku           = '' AND 
        @c_Channel       = '' AND 
        @c_C_Attribute01 = '' AND 
        @c_C_Attribute02 = '' AND 
        @c_C_Attribute03 = '' AND 
        @c_C_Attribute04 = '' AND 
        @c_C_Attribute05 = ''   
      ) AND
      ( @n_Channel_ID = 0 )
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 70010
      SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err) 
                    + ': Etiher Source Document/channel Attribute/ChannelID type is required'
                    + '. (isp_ValidateChannelInvHold )' 
      GOTO QUIT_SP
   END

   IF @c_HoldType IN ( '' ) 
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 70020
      SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err) + ': Invalid Hold Type' + @c_HoldType 
                    + '. (isp_ValidateChannelInvHold )' 
      GOTO QUIT_SP  
   END 

   IF @c_HoldType <> 'TRANHOLD' 
   BEGIN
      GOTO QUIT_SP  
   END
    
   IF @n_Channel_ID > 0
   BEGIN
      IF NOT EXISTS (SELECT 1 FROM ChannelInv WITH (NOLOCK) WHERE Channel_ID = @n_Channel_ID)
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 70030
         SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err) + ': Invalid Channel ID.' 
                        + '. (isp_ValidateChannelInvHold )' 
         GOTO QUIT_SP
      END
   END
   ELSE
   BEGIN
      IF @c_Facility  = '' OR 
         @c_Storerkey = '' OR 
         @c_Sku       = '' OR 
         @c_Channel   = '' 
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 70040
         SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err) 
                        + ': Facility, Storerkey, Sku & Channel is required for Channel Attribute hold'
                        + '. (isp_ValidateChannelInvHold )' 
         GOTO QUIT_SP
      END

      SET @c_SQL = N'SELECT @n_Cnt = 1'
                 + ' FROM ChannelInv WITH (NOLOCK)'
                 + ' WHERE Facility = @c_Facility'
                 + ' AND Storerkey= @c_Storerkey'
                 + ' AND Sku = @c_Sku'
                 + ' AND Channel = @c_Channel'
                 + CASE WHEN @c_C_Attribute01 = '' THEN '' ELSE ' AND C_Attribute01 = @c_C_Attribute01' END
                 + CASE WHEN @c_C_Attribute02 = '' THEN '' ELSE ' AND C_Attribute02 = @c_C_Attribute02' END
                 + CASE WHEN @c_C_Attribute03 = '' THEN '' ELSE ' AND C_Attribute03 = @c_C_Attribute03' END
                 + CASE WHEN @c_C_Attribute04 = '' THEN '' ELSE ' AND C_Attribute04 = @c_C_Attribute04' END
                 + CASE WHEN @c_C_Attribute05 = '' THEN '' ELSE ' AND C_Attribute05 = @c_C_Attribute05' END

      SET @c_SQLParms = N'@c_Facility        NVARCHAR(5)' 
                      + ',@c_Storerkey       NVARCHAR(15)'
                      + ',@c_Sku             NVARCHAR(20)'
                      + ',@c_Channel         NVARCHAR(20)'
                      + ',@c_C_Attribute01   NVARCHAR(30)'
                      + ',@c_C_Attribute02   NVARCHAR(30)'
                      + ',@c_C_Attribute03   NVARCHAR(30)'
                      + ',@c_C_Attribute04   NVARCHAR(30)'
                      + ',@c_C_Attribute05   NVARCHAR(30)'
                      + ',@n_Cnt             INT OUTPUT'

      EXEC sp_ExecuteSQL @c_SQL
                        ,@c_SQLParms
                        ,@c_Facility        
                        ,@c_Storerkey       
                        ,@c_Sku             
                        ,@c_Channel         
                        ,@c_C_Attribute01   
                        ,@c_C_Attribute02   
                        ,@c_C_Attribute03   
                        ,@c_C_Attribute04   
                        ,@c_C_Attribute05   
                        ,@n_Cnt           OUTPUT           
      IF @n_Cnt = 0 
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 70050
         SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err) 
                        + ': Channel Attribute Not found'
                        + '. (isp_ValidateChannelInvHold )' 
         GOTO QUIT_SP
      END
   END
QUIT_SP:
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_ValidateChannelInvHold '
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
END -- procedure

GO