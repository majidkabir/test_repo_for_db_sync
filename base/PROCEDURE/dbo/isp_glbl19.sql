SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure: isp_GLBL19                                          */
/* Creation Date: 07-Nov-2019                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-10981 [CN] Skechers B2B logic of generate labelno CR    */ 
/*                                                                      */
/* Input Parameters:  @c_PickSlipNo-Pickslipno, @n_CartonNo - CartonNo  */
/*                    Storerconfig: GenLabelNo_SP='isp_GLBL11'          */
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
/* 28-Nov-2019  CSCHONG  1.1  WMS-10981 - revised logic (CS01)          */
/************************************************************************/

CREATE PROC [dbo].[isp_GLBL19] ( 
         @c_PickSlipNo   NVARCHAR(10) 
      ,  @n_CartonNo     INT
      ,  @c_LabelNo      NVARCHAR(20)   OUTPUT )
AS
BEGIN
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
      
   DECLARE @n_StartTCnt     INT
          ,@n_Continue      INT
          ,@b_Success       INT 
          ,@n_Err           INT  
          ,@c_ErrMsg        NVARCHAR(255)
          ,@c_Label_SeqNo   NVARCHAR(9)
          ,@c_Prefix        NVARCHAR(30) 
		  ,@d_curdate       DATETIME
		  ,@c_curdate       NVARCHAR(10)
		  ,@c_datePrefix    NVARCHAR(2) 
		  ,@n_Len           INT         
		  ,@c_genlbllconfig NVARCHAR(5) 
		  ,@c_Identifier    NVARCHAR(2)  
          ,@c_Packtype      NVARCHAR(1)  
          ,@c_VAT           NVARCHAR(18)   
		  ,@c_Storerkey     NVARCHAR(15)  
          ,@c_Keyname       NVARCHAR(30)   
          ,@c_PackNo_Long   NVARCHAR(250) 
		  ,@c_nCounter      NVARCHAR(25)
   
   DECLARE @n_CheckDigit    INT
          ,@n_TotalCnt      INT
          ,@n_TotalOddCnt   INT
          ,@n_TotalEvenCnt  INT
          ,@n_Add           INT
          ,@n_Remain        INT
          ,@n_OddCnt        INT
          ,@n_EvenCnt       INT
          ,@n_Odd           INT
          ,@n_Even          INT
		  
   
   SET @n_StartTCnt         = @@TRANCOUNT
   SET @n_Continue          = 1
   SET @b_Success           = 0
   SET @n_Err               = 0
   SET @c_ErrMsg            = ''   
   SET @c_LabelNo           = ''
   SET @c_datePrefix        = ''
   SET @n_Len               = 8
   SET @c_genlbllconfig     = 0

   --CS01 START
   IF EXISTS (SELECT 1 FROM PACKHEADER PH (NOLOCK)
	          JOIN ORDERS O (NOLOCK) ON PH.loadkey = O.loadkey
	          JOIN CODELKUP C WITH (NOLOCK) ON C.LISTNAME = 'skeprintTC' and C.Storerkey = O.StorerKey and C.Short=O.ConsigneeKey
			  WHERE PH.Pickslipno = @c_Pickslipno)
   BEGIN	  
     SET @c_genlbllconfig = '1'
   END
  --CS01 END
 IF @c_genlbllconfig = '1'   --CS01
 BEGIN
   SET @d_curdate = GETDATE()
   SET @c_curdate = Convert(nvarchar(10),@d_curdate,101)
   SET @c_datePrefix = RIGHT(@c_curdate,2)
	 
	 SELECT TOP 1 @c_Prefix = C.Short
	 FROM PACKHEADER PH (NOLOCK)
	 JOIN ORDERS O (NOLOCK) ON PH.loadkey = O.loadkey
	 JOIN CODELKUP C WITH (NOLOCK) ON C.LISTNAME = 'Gen_LabelN' and C.Storerkey = O.StorerKey  
	 WHERE PH.Pickslipno = @c_Pickslipno

   IF ISNULL(@c_Prefix,'') = ''
   BEGIN
      SELECT @n_Continue = 3         
      SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38010   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
      SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Empty Prefix(RDD) (isp_GLBL19)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
      GOTO QUIT_SP
   END
	 
	 EXECUTE dbo.nspg_GetKey           
           'SKELBLNO',                      
           8,                               
           @c_Label_SeqNo OUTPUT,           
           @b_Success     OUTPUT,           
           @n_err         OUTPUT,           
           @c_errmsg      OUTPUT            
                                   
   IF @b_Success <> 1                
   BEGIN
      SELECT @n_Continue = 3         
      SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38020   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
      SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Getkey(SKELBLNO) (isp_GLBL19)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
      GOTO QUIT_SP
   END

   SET @c_labelno = LTRIM(RTRIM(ISNULL(@c_Prefix,''))) + RIGHT('0000000' + LTRIM(RTRIM(ISNULL(@c_Label_SeqNo,''))),@n_Len)   	 	 
   END   --CS01 START
   ELSE
   BEGIN

   SELECT @c_Storerkey = ORDERS.Storerkey  
   FROM PICKHEADER (NOLOCK)  
   JOIN ORDERS (NOLOCK) ON PICKHEADER.Orderkey = ORDERS.Orderkey  
   WHERE PICKHEADER.PickHeaderkey = @c_Pickslipno  
     
   IF ISNULL(@c_Storerkey,'') = ''  
   BEGIN  
      SELECT TOP 1 @c_Storerkey = ORDERS.Storerkey  
      FROM PICKHEADER (NOLOCK)  
      JOIN ORDERS (NOLOCK) ON PICKHEADER.ExternOrderkey = ORDERS.Loadkey  
      WHERE PICKHEADER.PickHeaderkey = @c_Pickslipno  
      AND ISNULL(PICKHEADER.ExternOrderkey,'') <> ''  
   END
  
    IF EXISTS ( SELECT 1 FROM StorerConfig WITH (NOLOCK)  
               WHERE StorerKey = @c_StorerKey  
               AND ConfigKey = 'GenUCCLabelNoConfig'  
               AND SValue = '1')  
   BEGIN  
      SET @c_Identifier = '00'  
      SET @c_Packtype = '0'    
      SET @c_LabelNo = ''  
  
      SELECT @c_VAT = ISNULL(Vat,'')  
      FROM Storer WITH (NOLOCK)  
      WHERE Storerkey = @c_Storerkey  
        
      IF ISNULL(@c_VAT,'') = ''  
         SET @c_VAT = '000000000'  
  
      IF LEN(@c_VAT) <> 9   
         SET @c_VAT = RIGHT('000000000' + RTRIM(LTRIM(@c_VAT)), 9)  
  
      --(Wan01) - Fixed if not numeric  
      IF ISNUMERIC(@c_VAT) = 0   
      BEGIN  
         SET @n_Continue = 3  
         SET @n_Err = 60000  
         SET @c_errmsg = 'NSQL ' + CONVERT(NCHAR(5),@n_Err) + ': Vat is not a numeric value. (isp_GLBL19)'  
         GOTO QUIT_SP  
      END   
      --(Wan02) - Fixed if not numeric  
  
      SELECT @c_PackNo_Long = Long   
      FROM  CODELKUP (NOLOCK)  
      WHERE ListName = 'PACKNO'  
      AND Code = @c_Storerkey  
       
      IF ISNULL(@c_PackNo_Long,'') = ''  
         SET @c_Keyname = 'TBLPackNo'  
      ELSE  
         SET @c_Keyname = 'PackNo' + LTRIM(RTRIM(@c_PackNo_Long))  
            
      EXECUTE nspg_getkey  
      @c_Keyname ,  
      7,  
      @c_nCounter     Output ,  
      @b_success      = @b_success output,  
      @n_err          = @n_err output,  
      @c_errmsg       = @c_errmsg output,  
      @b_resultset    = 0,  
      @n_batch        = 1  
           
      SET @c_LabelNo = @c_Identifier + @c_Packtype + RTRIM(@c_VAT) + RTRIM(@c_nCounter) --+ @nCheckDigit  
  
      SET @n_Odd = 1  
      SET @n_OddCnt = 0  
      SET @n_TotalOddCnt = 0  
      SET @n_TotalCnt = 0  
  
      WHILE @n_Odd <= 20   
      BEGIN  
         SET @n_OddCnt = CAST(SUBSTRING(@c_LabelNo, @n_Odd, 1) AS INT)  
         SET @n_TotalOddCnt = @n_TotalOddCnt + @n_OddCnt  
         SET @n_Odd = @n_Odd + 2  
      END  
  
      SET @n_TotalCnt = (@n_TotalOddCnt * 3)   
     
      SET @n_Even = 2  
      SET @n_EvenCnt = 0  
      SET @n_TotalEvenCnt = 0  
  
      WHILE @n_Even <= 20   
      BEGIN  
         SET @n_EvenCnt = CAST(SUBSTRING(@c_LabelNo, @n_Even, 1) AS INT)  
         SET @n_TotalEvenCnt = @n_TotalEvenCnt + @n_EvenCnt  
         SET @n_Even = @n_Even + 2  
      END  
  
      SET @n_Add = 0  
      SET @n_Remain = 0  
      SET @n_CheckDigit = 0  
  
      SET @n_Add = @n_TotalCnt + @n_TotalEvenCnt  
      SET @n_Remain = @n_Add % 10  
      SET @n_CheckDigit = 10 - @n_Remain  
  
      IF @n_CheckDigit = 10   
         SET @n_CheckDigit = 0  
  
      SET @c_LabelNo = ISNULL(RTRIM(@c_LabelNo), '') + CAST(@n_CheckDigit AS NVARCHAR( 1))  
   END   -- GenUCCLabelNoConfig  
   ELSE  
   BEGIN  
      EXECUTE nspg_GetKey  
         'PACKNO',   
         10 ,  
         @c_LabelNo   OUTPUT,  
         @b_success  OUTPUT,  
         @n_err      OUTPUT,  
         @c_errmsg   OUTPUT  
   END    
  
   IF @c_labelno <> ''  
      SET @c_labelno = RIGHT(@c_labelno, 14)  

   END  --CS01 END

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
      EXECUTE nsp_logerror @n_err, @c_errmsg, "isp_GLBL19"
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