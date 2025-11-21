SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure: isp_GLBL22                                          */
/* Copyright: LF Logistics                                              */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver.  Purposes                                  */
/* 2020-05-29   Ung     1.0   WMS-13534 Created                         */
/************************************************************************/

CREATE PROC [dbo].[isp_GLBL22] ( 
         @c_PickSlipNo   NVARCHAR(10) 
      ,  @n_CartonNo     INT
      ,  @c_LabelNo      NVARCHAR(20)   OUTPUT )
AS
BEGIN
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
      
   DECLARE @n_StartTCnt          INT
         , @n_Continue           INT
         , @b_Success            INT 
         , @n_Err                INT  
         , @c_ErrMsg             NVARCHAR(255)
         
   DECLARE @c_Label_SeqNo        NVARCHAR(5)
          ,@c_Consigneekey       NVARCHAR(15)
          ,@c_Storerkey          NVARCHAR(15)
          ,@c_Keyname            NVARCHAR(18)
          ,@c_LoadKey            NVARCHAR(10)

   SET @n_StartTCnt        = @@TRANCOUNT
   SET @n_Continue         = 1
   SET @b_Success          = 0
   SET @n_Err              = 0
   SET @c_ErrMsg           = ''   
   SET @c_LabelNo          = ''
   
   -- Get PickSlip info
   SELECT 
      @c_ConsigneeKey = ISNULL( ConsigneeKey, ''), 
      @c_LoadKey = ISNULL( LoadKey,'')
   FROM PackHeader WITH (NOLOCK)
   WHERE PickSlipNo = @c_PickSlipNo

   -- Conso pack, get random consignee
   IF @c_ConsigneeKey = ''
   BEGIN
      IF @c_LoadKey <> ''
         SELECT TOP 1 
            @c_ConsigneeKey = ConsigneeKey
         FROM Orders WITH (NOLOCK)
         WHERE LoadKey = @c_LoadKey
   END
   
   -- Check consignee
   IF @c_ConsigneeKey = ''
   BEGIN
      SET @n_continue = 3        
      SET @n_err = 60010          
      SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': No ConsigneeKey. (isp_GLBL22)'         
      GOTO QUIT_SP  
   END

   -- Pad 0 to consignee
   IF LEN( @c_ConsigneeKey) < 6
      SET @c_ConsigneeKey = RIGHT( '000000' + @c_ConsigneeKey, 6)
   
   -- Get new running no
   EXECUTE dbo.nspg_GetKey
      'InditexLabelNo',
      5,
      @c_Label_SeqNo OUTPUT,
      @b_Success     OUTPUT,
      @n_Err         OUTPUT,
      @c_ErrMsg      OUTPUT
   IF @b_Success <> 1
   BEGIN
      SET @n_continue = 3        
      SET @n_err = 60010          
      SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': nspg_GetKey error (isp_GLBL22)'         
      GOTO QUIT_SP  
   END
   
   -- Generate labelNo   
   SET @c_LabelNo = @c_ConsigneeKey + @c_Label_SeqNo
   
   QUIT_SP:

   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SELECT @b_Success = 0     
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt 
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, "isp_GLBL22"
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE 
   BEGIN
      SELECT @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt 
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END

END

GO