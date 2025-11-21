SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure: isp_GLBL18                                          */
/* Creation Date: 18-Sep-2019                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-10603 CN PVHQHW UCC Label no                            */ 
/*                                                                      */
/* Input Parameters:  @c_PickSlipNo-Pickslipno, @n_CartonNo - CartonNo  */
/*                    Storerconfig: GenLabelNo_SP='isp_GLBL18'          */
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
/* 24-Aug-2022  WLChooi  1.1  WMS-20608 - Cater for ECOM (WL01)         */
/* 24-Aug-2022  WLChooi  1.1  DevOps Combine Script                     */
/************************************************************************/

CREATE PROC [dbo].[isp_GLBL18] ( 
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

   --WL01 S
   DECLARE    
      @c_Identifier    NVARCHAR(2),
      @c_Packtype      NVARCHAR(1),
      @c_VAT           NVARCHAR(18),
      @c_nCounter      NVARCHAR(25),
      @c_Keyname       NVARCHAR(30), 
      @c_PackNo_Long   NVARCHAR(250),
      @c_Storerkey     NVARCHAR(15)
   --WL01 E
   
   SET @n_StartTCnt         = @@TRANCOUNT
   SET @n_Continue          = 1
   SET @b_Success           = 0
   SET @n_Err               = 0
   SET @c_ErrMsg            = ''   
   SET @c_LabelNo           = ''
   
   --WL01 S
   --ECOM Packing
   IF EXISTS (SELECT 1
              FROM PACKHEADER PH (NOLOCK)
              JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = PH.OrderKey
              WHERE PH.PickSlipNo = @c_PickSlipNo
              AND OH.DocType = 'E')
   BEGIN
      SELECT @c_Storerkey = Storerkey
      FROM PACKHEADER WITH (NOLOCK)
      WHERE PickSlipNo = @c_PickSlipNo

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
      
         IF ISNUMERIC(@c_VAT) = 0 
         BEGIN
            SET @n_Continue = 3
            SET @n_Err = 38009
            SET @c_errmsg = 'NSQL ' + CONVERT(NCHAR(5),@n_Err) + ': Vat is not a numeric value. (isp_GLBL18)'
            GOTO QUIT_SP
         END 
      
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
            
         SET @c_LabelNo = @c_Identifier + @c_Packtype + RTRIM(@c_VAT) + RTRIM(@c_nCounter) --+ @n_CheckDigit
      
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

      GOTO QUIT_SP
   END
   --WL01 E
    
   --Discrete
   SELECT TOP 1 @c_Prefix = CL.UDF03 
   FROM PICKHEADER PH (NOLOCK)
   JOIN ORDERS O (NOLOCK) ON PH.Orderkey = O.Orderkey
   JOIN CODELKUP CL (NOLOCK) ON CL.LISTNAME = 'PVHQHWFAC' AND CL.Short = O.Facility AND CL.Storerkey = O.Storerkey
   WHERE PH.Pickheaderkey = @c_Pickslipno
   
   --Conso
   IF ISNULL(@c_Prefix,'') = ''
   BEGIN
      SELECT TOP 1 @c_Prefix = CL.UDF03
      FROM PICKHEADER PH (NOLOCK)
      JOIN ORDERS O (NOLOCK) ON PH.ExternOrderkey = O.Loadkey
      JOIN CODELKUP CL (NOLOCK) ON CL.LISTNAME = 'PVHQHWFAC' AND CL.Short = O.Facility AND CL.Storerkey = O.Storerkey
      WHERE PH.Pickheaderkey = @c_Pickslipno       
   END

   IF ISNULL(@c_Prefix,'') = ''
   BEGIN
      SELECT @n_Continue = 3         
      SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38010   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
      SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Empty Prefix(RDD) (isp_GLBL18)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
      GOTO QUIT_SP
   END 
    
    EXECUTE dbo.nspg_GetKey           
           'PVHQHWLBLNO',                      
           9,                               
           @c_Label_SeqNo OUTPUT,           
           @b_Success     OUTPUT,           
           @n_err         OUTPUT,           
           @c_errmsg      OUTPUT            
                                   
   IF @b_Success <> 1                
   BEGIN
      SELECT @n_Continue = 3         
      SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38020   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
      SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Getkey(PVHLBLNO) (isp_GLBL18)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
      GOTO QUIT_SP
   END

   SET @c_labelno = LTRIM(RTRIM(ISNULL(@c_Prefix,''))) + LTRIM(RTRIM(ISNULL(@c_Label_SeqNo,'')))  
   
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
   
   SET @c_LabelNo = ISNULL(RTRIM(@c_LabelNo), '') + CAST(@n_CheckDigit AS NVARCHAR(1))            
   
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, "isp_GLBL18"
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