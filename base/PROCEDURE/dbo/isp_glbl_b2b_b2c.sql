SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure: isp_GLBL_B2B_B2C                                    */
/* Creation Date: 04-Jun-2018                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-5182 CN ANF Use storerconfig option1 & 2 to configure   */ 
/*          custom gen labelno sp for B2B and B2C                       */
/*                                                                      */
/* Input Parameters:  @c_PickSlipNo-Pickslipno, @n_CartonNo - CartonNo  */
/*                    Storerconfig: GenLabelNo_SP='isp_GLBL_B2B_B2C'    */
/*                                                                      */
/* Output Parameters:                                                   */
/*                                                                      */
/* Usage: Call from isp_GenLabelNo_Wrapper                              */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 20-Jul-2018  NJOW01   1.0  Fix - allow RDT call with additional parm */
/************************************************************************/

CREATE PROC [dbo].[isp_GLBL_B2B_B2C] ( 
         @c_PickSlipNo         NVARCHAR(10) 
      ,  @n_CartonNo           INT
      ,  @c_LabelNo            NVARCHAR(20)   OUTPUT 
      ,  @cStorerKey           NVARCHAR( 15) = ''  --NJOW01
      ,  @cDeviceProfileLogKey NVARCHAR(10)  = '' 
      ,  @cConsigneeKey        NVARCHAR(15)  = ''
      ,  @b_success            int = 0 OUTPUT 
      ,  @n_err                int = 0 OUTPUT
      ,  @c_errmsg             NVARCHAR(225) = '' OUTPUT
      )
AS
BEGIN
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
      
   DECLARE @n_StartTCnt     INT
          ,@n_Continue      INT
          --,@b_Success       INT 
          --,@n_Err           INT  
          --,@c_ErrMsg        NVARCHAR(255)
          ,@c_DocType       NCHAR(1)
          ,@c_Storerkey     NVARCHAR(10)
          ,@c_Facility      NVARCHAR(5)
          ,@c_B2B_SP        NVARCHAR(50)
          ,@c_B2C_SP        NVARCHAR(50)
          ,@c_SPCode        NVARCHAR(50)
          ,@c_SQL           NVARCHAR(MAX)             
   
   SET @n_StartTCnt         = @@TRANCOUNT
   SET @n_Continue          = 1
   SET @b_Success           = 0
   SET @n_Err               = 0
   SET @c_ErrMsg            = ''   
   --SET @c_LabelNo           = ''
	 
	 IF @@TRANCOUNT = 0
	    BEGIN TRAN
	 
	 SELECT @c_DocType = O.DocType,
	        @c_Storerkey = O.Storerkey,
	        @c_Facility = O.Facility 
	 FROM PICKHEADER PH (NOLOCK)
	 JOIN ORDERS O (NOLOCK) ON PH.Orderkey = O.Orderkey
	 WHERE PH.Pickheaderkey = @c_PickSlipNo
	 
	 IF ISNULL(@c_DocType,'') = ''
	 BEGIN
   	  SELECT TOP 1 @c_DocType = O.DocType,
         	         @c_Storerkey = O.Storerkey,
	                 @c_Facility = O.Facility 
	    FROM PICKHEADER PH (NOLOCK)
	    JOIN ORDERS O (NOLOCK) ON PH.ExternOrderkey = O.Loadkey
	    WHERE PH.Pickheaderkey = @c_PickSlipNo
	 END
	 
	 SELECT TOP 1 @c_B2B_SP = Option1,
	              @c_B2C_SP = Option2
   FROM   STORERCONFIG (NOLOCK) 
   WHERE  StorerKey = @c_StorerKey
   AND    ConfigKey = 'GenLabelNo_SP'  
   AND    Svalue = 'isp_GLBL_B2B_B2C'
   AND    (Facility = @c_Facility OR Facility = '' OR Facility IS NULL)
   ORDER BY CASE WHEN ISNULL(Facility,'') <> '' THEN 1 ELSE 2 END
   
   IF NOT EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@c_B2B_SP) AND type = 'P')
   BEGIN
      SELECT @n_Continue = 3         
      SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38010   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
      SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid B2B stored proc name: ' + RTRIM(ISNULL(@c_B2B_SP,'')) + ' at Storerconfig GenLabelNo_SP Option1 (isp_GLBL_B2B_B2C)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
      GOTO QUIT_SP      
   END

   IF NOT EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@c_B2C_SP) AND type = 'P')
   BEGIN
      SELECT @n_Continue = 3         
      SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38020   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
      SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid B2C stored proc name: ' + RTRIM(ISNULL(@c_B2C_SP,'')) + ' at Storerconfig GenLabelNo_SP Option2 (isp_GLBL_B2B_B2C)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
      GOTO QUIT_SP      
   END

	 IF @c_DocType = 'E'
	    SET @c_SPCode = @c_B2C_SP
	 ELSE
	    SET @c_SPCode = @c_B2B_SP
   
   IF EXISTS(SELECT 1
             FROM [INFORMATION_SCHEMA].[PARAMETERS]                 
             WHERE SPECIFIC_NAME = @c_SPCode             
             AND PARAMETER_NAME = '@cDeviceProfileLogKey') --NJOW01
   BEGIN
   	  --NJOW01
      SET @c_SQL = 'EXEC ' + RTRIM(@c_SPCode) + ' @c_PickSlipNo, @n_CartonNo, @c_LabelNo OUTPUT, @cStorerKey, @cDeviceProfileLogKey, @cConsigneeKey, @b_Success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT '
      
      EXEC sp_executesql @c_SQL 
         ,  N'@c_PickSlipNo NVARCHAR(10), @n_CartonNo INT, @c_LabelNo NVARCHAR(20) OUTPUT, @cStorerKey NVARCHAR(15), @cDeviceProfileLogKey NVARCHAR(10), @cConsigneeKey NVARCHAR(15), @b_Success INT OUTPUT, @n_Err INT OUTPUT, @c_ErrMsg NVARCHAR(225) OUTPUT' 
         ,  @c_PickSlipNo
         ,  @n_CartonNo   
         ,  @c_LabelNo OUTPUT                        
         ,  @cStorerKey           
         ,  @cDeviceProfileLogKey 
         ,  @cConsigneeKey        
         ,  @b_success OUTPUT           
         ,  @n_err     OUTPUT     
         ,  @c_errmsg  OUTPUT      
   	  
      IF @b_Success <> 1
      BEGIN
         SELECT @n_Continue = 3  
         GOTO QUIT_SP
      END   	
   END         
   ELSE
   BEGIN                                                     
      SET @c_SQL = 'EXEC ' + RTRIM(@c_SPCode) + ' @c_PickSlipNo, @n_CartonNo, @c_LabelNo OUTPUT'
      
      EXEC sp_executesql @c_SQL 
         ,  N'@c_PickSlipNo NVARCHAR(10), @n_CartonNo INT, @c_LabelNo NVARCHAR(20) OUTPUT' 
         ,  @c_PickSlipNo
         ,  @n_CartonNo   
         ,  @c_LabelNo OUTPUT                        
   END
	   
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, "isp_GLBL_B2B_B2C"
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