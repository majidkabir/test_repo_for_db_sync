SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure: isp_GLBL27                                          */
/* Creation Date: 16-Nov-2020                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-15594 [CN] Pentland_WMS_LabelNo_Generation_CR           */ 
/*                                                                      */
/* Input Parameters:  @c_PickSlipNo-Pickslipno, @n_CartonNo - CartonNo  */
/*                    Storerconfig: GenLabelNo_SP='isp_GLBL27'          */
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
/************************************************************************/

CREATE PROC [dbo].[isp_GLBL27] ( 
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
          ,@c_loadkey       NVARCHAR(20)

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
   SET @c_Prefix            = ''
   SET @c_keyname           = ''
   SET @c_loadkey           = ''

   SELECT @c_loadkey = loadkey
   FROM PACKHEADER PH (NOLOCK)
   WHERE Pickslipno = @c_Pickslipno
  
  IF @c_loadkey <> ''
  BEGIN
    SELECT TOP 1 @c_Prefix = C.long
                ,@c_keyname = C.Short
                ,@c_Storerkey = O.Storerkey
    FROM PACKHEADER PH (NOLOCK)
    JOIN ORDERS O (NOLOCK) ON PH.loadkey = O.loadkey
    JOIN CODELKUP C WITH (NOLOCK) ON C.LISTNAME = 'Gen_PLLBLN' and C.Storerkey = O.StorerKey and C.code = O.dischargeplace 
    WHERE PH.Pickslipno = @c_Pickslipno
  END
  ELSE
  BEGIN
     SELECT TOP 1 @c_Prefix = C.long
                ,@c_keyname = C.Short
                ,@c_Storerkey = O.Storerkey
    FROM PACKHEADER PH (NOLOCK)
    JOIN ORDERS O (NOLOCK) ON PH.Orderkey = O.Orderkey
    JOIN CODELKUP C WITH (NOLOCK) ON C.LISTNAME = 'Gen_PLLBLN' and C.Storerkey = O.StorerKey and C.code = O.dischargeplace 
    WHERE PH.Pickslipno = @c_Pickslipno  
  END

   IF ISNULL(@c_Prefix,'') = ''
   BEGIN
      SELECT @n_Continue = 3         
      SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38010   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
      SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Empty Prefix (isp_GLBL27)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
      GOTO QUIT_SP
   END

   IF ISNULL(@c_keyname,'') = ''
   BEGIN
      SELECT @n_Continue = 3         
      SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38020   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
      SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Empty keyname (isp_GLBL27)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
      GOTO QUIT_SP
   END
  
    IF EXISTS ( SELECT 1 FROM StorerConfig WITH (NOLOCK)  
               WHERE StorerKey = @c_StorerKey  
               AND ConfigKey = 'GenUCCLabelNoConfig'  
               AND SValue = '1')  
   BEGIN  
      SET @c_Identifier = '00'  
      SET @c_Packtype = '4'    
      SET @c_LabelNo = ''  
            
      EXECUTE nspg_getkey  
      @c_Keyname ,  
      9,  
      @c_nCounter     Output ,  
      @b_success      = @b_success output,  
      @n_err          = @n_err output,  
      @c_errmsg       = @c_errmsg output,  
      @b_resultset    = 0,  
      @n_batch        = 1  
           
      SET @c_LabelNo = @c_Identifier + @c_Packtype + RTRIM(@c_Prefix) + RTRIM(@c_nCounter) --+ @nCheckDigit  
  
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
  
   IF @c_labelno <> ''  
      SET @c_labelno = RIGHT(@c_labelno, 20)  

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
      EXECUTE nsp_logerror @n_err, @c_errmsg, "isp_GLBL27"
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