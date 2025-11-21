SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure: isp_GLBL08                                          */
/* Creation Date: 07-Mar-2016                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: SOS#                                                        */ 
/*                                                                      */
/* Input Parameters:  @c_PickSlipNo-Pickslipno, @n_CartonNo - CartonNo  */
/*                    Storerconfig: GenLabelNo_SP='isp_GLBL08'          */
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
/* 12-OCT-2016  NJOW01   1.0  WMS-507 set label logic by storerconfig   */    
/* 08-Nov-2016  tlting   1.1  blocking issue - change to getkey seq     */ 
/* 24-JUL-2017  Wan01    1.1  WMS-2306 - CN-Nike SDC WMS ECOM Packing CR*/      
/* 17-Nov-2017  tlting01 1.2  Performance Tuning                        */      
/************************************************************************/

CREATE PROC [dbo].[isp_GLBL08] ( 
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
         , @c_Storerkey          NVARCHAR(15)
   
   DECLARE @n_CheckDigit    INT,
           @n_TotalCnt      INT,
           @n_TotalOddCnt   INT,
           @n_TotalEvenCnt  INT,
           @n_Add           INT,
           @n_Remain        INT,
           @n_OddCnt        INT,
           @n_EvenCnt       INT,
           @n_Odd           INT,
           @n_Even          INT,
           @c_RangeDC74     NVARCHAR(9)
   
   --NJOW01        
   DECLARE @c_Prefix        NVARCHAR(10),          
           @n_Min           INT,
           @n_Max           INT,
           @c_Keyname       NVARCHAR(18),
           @c_facility      NVARCHAR(5),
           @n_len           INT,
           @c_authority     NVARCHAR(30),
           @c_option1 NVARCHAR(50),
           @c_option2 NVARCHAR(50),
           @c_option3 NVARCHAR(50),
           @c_option4 NVARCHAR(50),
           @c_option5 NVARCHAR(4000)
                    
   SET @c_Prefix = '0000015674'
   SET @n_Min = 742000000   
   SET @n_Max = 749999999
   SET @c_Keyname = 'DC74'
   SET @n_Len = 9
                       
   SET @n_StartTCnt        = @@TRANCOUNT
   SET @n_Continue         = 1
   SET @b_Success          = 0
   SET @n_Err              = 0
   SET @c_ErrMsg           = ''
   
   SET @c_RangeDC74 = ''
	 SET @c_LabelNo = ''
	 
	 ----NJOW01
	 SELECT TOP 1 @c_Storerkey = O.Storerkey,
	              @c_Facility = O.Facility
	 FROM PICKHEADER PH (NOLOCK)
	 JOIN ORDERS O (NOLOCK) ON O.Orderkey = PH.Orderkey
	 WHERE PH.Pickheaderkey = @c_Pickslipno
	 
	 IF ISNULL(@c_Storerkey,'') = ''
	 BEGIN
	    SELECT TOP 1 @c_Storerkey = O.Storerkey,
	                 @c_Facility = O.Facility
	    FROM PICKHEADER PH (NOLOCK)
	    JOIN loadplandetail LPD (NOLOCK) ON LPD.Loadkey = PH.ExternOrderkey   -- tlting01
	    JOIN ORDERS O (NOLOCK) ON O.Orderkey = LPD.Orderkey
	    WHERE PH.Pickheaderkey = @c_Pickslipno
	    AND ISNULL(PH.Orderkey,'') = ''
	 END

    --(Wan01) - START
   IF ISNULL(@c_StorerKey,'') = ''
   BEGIN
      SELECT TOP 1 @c_StorerKey = PACKHEADER.Storerkey
      FROM PACKHEADER (NOLOCK)
      WHERE PACKHEADER.PickSlipNo = @c_PickSlipNo
   END
   --(Wan01) - END

   --NJOW01	 
   Execute nspGetRight 
   @c_facility,  
   @c_StorerKey,              
   '', -- @c_SKU,                    
   'GenLabelNo_SP', -- Configkey
   @b_success    OUTPUT,
   @c_authority  OUTPUT,
   @n_err        OUTPUT,
   @c_errmsg     OUTPUT,
   @c_option1 OUTPUT,  --prefix
   @c_option2 OUTPUT,  --keyname
   @c_option3 OUTPUT,  --mix
   @c_option4 OUTPUT,  --max
   @c_option5 OUTPUT
  
   IF @c_authority = 'isp_GLBL08'
   BEGIN
   	  IF ISNULL(@c_option1,'') <> ''
   	     SET @c_Prefix = @c_Option1
       
   	  IF ISNULL(@c_option2,'') <> ''
   	     SET @c_keyname = @c_Option2
       
   	  IF ISNUMERIC(@c_option3) = 1 AND ISNUMERIC(@c_option4) = 1
   	  BEGIN
   	     SET @n_Min = CAST(@c_option3 AS INT)
   	     SET @n_Max = CAST(@c_option4 AS INT)
   	     IF LEN(@c_option4) > 1
   	        SET @n_Len = LEN(@c_option4)
   	  END   	        	           
   END
   
   IF  @c_Keyname = 'DC74'
   BEGIN
            
      --NJOW01
      EXECUTE dbo.nspg_GetKey   
             'DC74',   
             @n_Len,  
             @c_RangeDC74 OUTPUT,   
             @b_Success OUTPUT,   
             @n_Err OUTPUT,   
             @c_Errmsg OUTPUT  
   END
   ELSE
   BEGIN
          
      EXECUTE dbo.nspg_GetKeyMinMax   
             @c_keyname,   
             @n_Len,   
             @n_Min,
             @n_Max,
             @c_RangeDC74 OUTPUT,   
             @b_Success OUTPUT,   
             @n_Err OUTPUT,   
             @c_Errmsg OUTPUT        
   END       

   IF @b_success <> 1
   BEGIN
      SELECT @n_continue = 3  
      SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38030   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
      SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Getkey(DC74) (isp_GLBL08)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
      GOTO QUIT_SP
   END
   
   SET @c_labelno = LTRIM(RTRIM(ISNULL(@c_Prefix,''))) + LTRIM(RTRIM(ISNULL(@c_RangeDC74,'')))  --NJOW01
   --SET @c_labelno = '0000015674' + RTRIM(ISNULL(@c_RangeDC74,'')) 
   
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, "isp_GLBL08"
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