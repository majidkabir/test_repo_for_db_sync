SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure: isp_GLBL13                                          */
/* Creation Date: 26-Nov-2018                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-7807 TW Generate label no with carton track             */ 
/*                                                                      */
/* Input Parameters:  @c_PickSlipNo-Pickslipno, @n_CartonNo - CartonNo  */
/*                    Storerconfig: GenLabelNo_SP='isp_GLBL13'          */
/*                                                                      */
/* Output Parameters:                                                   */
/*                                                                      */
/* Usage: Call from isp_GenLabelNo_Wrapper                              */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 21-Mar-2019  NJOW01   1.0  Fix Check Digit                           */
/* 02-May-2019  WLCHOOI  1.1  WMS-8871 - No need to update trackingNo   */
/*                                       into Orders table (WL01)       */
/************************************************************************/
CREATE PROC [dbo].[isp_GLBL13] ( 
         @c_PickSlipNo   NVARCHAR(10) 
      ,  @n_CartonNo     INT
      ,  @c_LabelNo      NVARCHAR(20)   OUTPUT )
AS
BEGIN
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE  @n_Continue      INT
           ,@b_Success       INT 
           ,@n_Err           INT  
           ,@c_ErrMsg        NVARCHAR(255)
           ,@n_StartTCnt     INT
           ,@c_Storerkey     NVARCHAR(15)
           ,@cIdentifier     NVARCHAR(2)
           ,@cPacktype       NVARCHAR(1)
           ,@cVAT            NVARCHAR(18)
           ,@nCheckDigit     INT     
           ,@cPackNo_Long    NVARCHAR(250)
           ,@cKeyname        NVARCHAR(30) 
           ,@c_nCounter      NVARCHAR(25)
           ,@nTotalCnt       INT
           ,@nTotalOddCnt    INT
           ,@nTotalEvenCnt   INT
           ,@nAdd            INT
           ,@nDivide         INT
           ,@nRemain         INT
           ,@nOddCnt         INT
           ,@nEvenCnt        INT
           ,@nOdd            INT
           ,@nEven           INT
           ,@c_Orderkey      NVARCHAR(10)
           ,@c_Shipperkey    NVARCHAR(15)
           ,@c_UDF01         NVARCHAR(60)
           ,@c_UDF02         NVARCHAR(60)
           ,@c_UDF03         NVARCHAR(60)
           ,@c_Code          NVARCHAR(30)
           ,@c_TrackingNo    NVARCHAR(60)
           ,@c_OrdTrackingNo NVARCHAR(30)
           ,@n_Findcartonno  INT
           ,@n_CheckDigit    INT

   SELECT @n_StartTCnt=@@TRANCOUNT, @n_continue=1, @b_success=1, @c_errmsg='', @n_err=0 
   SET @c_LabelNo = ''
   
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
      SET @cIdentifier = '00'
      SET @cPacktype = '0'  
      SET @c_LabelNo = ''

      SELECT @cVAT = ISNULL(Vat,'')
      FROM Storer WITH (NOLOCK)
      WHERE Storerkey = @c_Storerkey
      
      IF ISNULL(@cVAT,'') = ''
         SET @cVAT = '000000000'

      IF LEN(@cVAT) <> 9 
         SET @cVAT = RIGHT('000000000' + RTRIM(LTRIM(@cVAT)), 9)

      IF ISNUMERIC(@cVAT) = 0 
      BEGIN
         SELECT @n_Continue = 3         
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38010   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Vat is not a numeric value. (isp_GLBL13)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
         GOTO QUIT_SP
      END 

      SELECT @cPackNo_Long = Long 
      FROM  CODELKUP (NOLOCK)
      WHERE ListName = 'PACKNO'
      AND Code = @c_Storerkey
     
      IF ISNULL(@cPackNo_Long,'') = ''
         SET @cKeyname = 'TBLPackNo'
      ELSE
         SET @cKeyname = 'PackNo' + LTRIM(RTRIM(@cPackNo_Long))
          
      EXECUTE nspg_getkey
      @cKeyname ,
      7,
      @c_nCounter     Output ,
      @b_success      = @b_success output,
      @n_err          = @n_err output,
      @c_errmsg       = @c_errmsg output,
      @b_resultset    = 0,
      @n_batch        = 1
         
      SET @c_LabelNo = @cIdentifier + @cPacktype + RTRIM(@cVAT) + RTRIM(@c_nCounter) 

      SET @nOdd = 1
      SET @nOddCnt = 0
      SET @nTotalOddCnt = 0
      SET @nTotalCnt = 0

      WHILE @nOdd <= 20 
      BEGIN
         SET @nOddCnt = CAST(SUBSTRING(@c_LabelNo, @nOdd, 1) AS INT)
         SET @nTotalOddCnt = @nTotalOddCnt + @nOddCnt
         SET @nOdd = @nOdd + 2
      END

      SET @nTotalCnt = (@nTotalOddCnt * 3) 
   
      SET @nEven = 2
      SET @nEvenCnt = 0
      SET @nTotalEvenCnt = 0

      WHILE @nEven <= 20 
      BEGIN
         SET @nEvenCnt = CAST(SUBSTRING(@c_LabelNo, @nEven, 1) AS INT)
         SET @nTotalEvenCnt = @nTotalEvenCnt + @nEvenCnt
         SET @nEven = @nEven + 2
      END

      SET @nAdd = 0
      SET @nRemain = 0
      SET @nCheckDigit = 0

      SET @nAdd = @nTotalCnt + @nTotalEvenCnt
      SET @nRemain = @nAdd % 10
      SET @nCheckDigit = 10 - @nRemain

      IF @nCheckDigit = 10 
         SET @nCheckDigit = 0

      SET @c_LabelNo = ISNULL(RTRIM(@c_LabelNo), '') + CAST(@nCheckDigit AS NVARCHAR( 1))
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
   
   ---------Generate carton track---------   
   SELECT @c_Orderkey = O.Orderkey,
          @c_Shipperkey = O.Shipperkey,
          @c_OrdTrackingNo = O.TrackingNo
   FROM PICKHEADER PH (NOLOCK)
   JOIN ORDERS O (NOLOCK) ON PH.Orderkey = O.Orderkey
   WHERE PH.Pickheaderkey = @c_Pickslipno
   
	 IF ISNULL(@c_Shipperkey,'') = ''
	 BEGIN
      SELECT @n_Continue = 3         
      SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38020   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
      SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+':Order#'  + RTRIM(@c_Orderkey) + '. Empty Shipperkey is not allowed. (isp_GLBL13)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           	 	  
	 	  GOTO QUIT_SP
	 END
	 	 
	 SELECT @c_Code = Code, 
	        @c_UDF01 = UDF01, --Min number
	        @c_UDF02 = UDF02, --Max number
	        @c_UDF03 = UDF03 --Current number
	 FROM CODELKUP (NOLOCK) 
	 WHERE Listname ='TRACKNO'
	 AND Code = @c_Shipperkey	 
	 AND Storerkey = @c_Storerkey
	 AND Short = 'ORDER' 
	 
	 IF ISNULL(@c_Code,'') = ''
	 BEGIN
      SELECT @n_Continue = 3         
      SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38030   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
      SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+':Order#'  + RTRIM(@c_Orderkey) + '. Tracking Number configuration not yet setup for ' + RTRIM(@c_Shipperkey) + '. (isp_GLBL13)'  + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           	 	  
	 	  GOTO QUIT_SP
	 END
	 
	 IF ISNUMERIC(@c_UDF01) <>  1 OR ISNUMERIC(@c_UDF02) <>  1 OR @c_UDF01 > @c_UDF02
	 BEGIN
      SELECT @n_Continue = 3         
      SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38040   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
      SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid Tracking Number range setup for ' + RTRIM(@c_Shipperkey) + '. (isp_GLBL13)'  + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           	 	  
	 	  GOTO QUIT_SP
	 END	    	 
	 
	 IF ISNUMERIC(@c_UDF03) <> 1	    	    
	    SET @c_UDF03 = @c_UDF01
	    
	 SET @c_UDF03 = RTRIM(LTRIM(CONVERT(NVARCHAR, CAST(@c_UDF03 AS BIGINT) + 1)))
	 
	 IF @c_UDF03 > @c_UDF02
	 BEGIN
      SELECT @n_Continue = 3         
      SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38050   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
      SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Order# ' + RTRIM(@c_Orderkey) + '. New Tracking Number ' + RTRIM(@c_UDF03) + ' exceeded limit for ' + RTRIM(@c_Shipperkey) + '. (isp_GLBL13)'  + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           	 	  
	 	 GOTO QUIT_SP
	 END

   --NJOW01	 
	 SELECT @n_CheckDigit =  
        (CAST(SUBSTRING(@c_UDF03,1,1) AS INT)+
	       CAST(SUBSTRING(@c_UDF03,2,1) AS INT)+
	       CAST(SUBSTRING(@c_UDF03,3,1) AS INT)+
	       CAST(SUBSTRING(@c_UDF03,4,1) AS INT)+
         CAST(SUBSTRING(@c_UDF03,5,1) AS INT)+
	       CAST(SUBSTRING(@c_UDF03,6,1) AS INT)+
	       CAST(SUBSTRING(@c_UDF03,7,1) AS INT)+
	       CAST(SUBSTRING(@c_UDF03,8,1) AS INT)+
         CAST(SUBSTRING(@c_UDF03,9,1) AS INT)+
	       CAST(SUBSTRING(@c_UDF03,10,1) AS INT)+
	       CAST(SUBSTRING(@c_UDF03,11,1) AS INT)) % 7
	 
	 --SET @c_TrackingNo =  RTRIM(LTRIM(CONVERT(NVARCHAR,(CAST(@c_UDF03 AS BIGINT) * 10)))) + LTRIM(RTRIM(CAST(@n_Checkdigit AS NVARCHAR)))  --(CAST(@c_UDF03 AS BIGINT) % 7))))
	 SET @c_TrackingNo =  RTRIM(LTRIM(@c_UDF03)) + LTRIM(RTRIM(CAST(@n_Checkdigit AS NVARCHAR)))  --(CAST(@c_UDF03 AS BIGINT) % 7))))
	 
	 SET @n_findcartonno = 0
	 SELECT @n_findcartonno = cartonno
	 FROM PACKDETAIL(NOLOCK)
	 WHERE Pickslipno = @c_Pickslipno
	 AND LabelNo = @c_LabelNo
	 
	 /*IF ISNULL(@n_findcartonno,0) = 0	
	 BEGIN
	    SELECT @n_findcartonno = MAX(ISNULL(cartonno, 0)) + 1
	    FROM PACKDETAIL(NOLOCK)
	    WHERE Pickslipno = @c_Pickslipno
	    END
	 END*/ --WL01 Comment Out
	 
	 --WL01 Start
	 IF ISNULL(@n_findcartonno,0) = 0	
	 BEGIN
	    IF EXISTS (SELECT 1 FROM PACKDETAIL (NOLOCK) WHERE Pickslipno = @c_Pickslipno)
	    BEGIN
	       SELECT @n_findcartonno = MAX(ISNULL(cartonno, 0)) + 1
	       FROM PACKDETAIL(NOLOCK)
	       WHERE Pickslipno = @c_Pickslipno
	    END
	    ELSE
	    BEGIN
	       SELECT @n_findcartonno = 1
	    END
	 END
	 --WL01 End
	 
	 SELECT @n_Cartonno = @n_findcartonno
	 
	 INSERT INTO CARTONTRACK (LabelNo, CarrierName, KeyName, TrackingNo, CarrierRef1, UDF01, UDF02, CarrierRef2)
	    VALUES (@c_Orderkey, @c_Shipperkey, 'ORDERS', @c_TrackingNo, '01',@c_Pickslipno, @c_LabelNo, CAST(@n_CartonNo AS NVARCHAR))
	 
	 UPDATE CODELKUP WITH (ROWLOCK)
	 SET UDF03 = @c_UDF03
	 WHERE Listname ='TRACKNO'
	 AND Code = @c_Shipperkey 
	 AND Storerkey = @c_Storerkey
	 AND Short = 'ORDER'	    	    
	 
    --Comment out the codes below (WL01)
	 --IF ISNULL(@c_OrdTrackingNo,'') = ''
	 --BEGIN
	 --   UPDATE ORDERS WITH (ROWLOCK)
	 --   SET TrackingNo = @c_TrackingNo,
  --        TrafficCop = NULL
	 --   WHERE OrderKey = @c_Orderkey
	 --END	    	   
         
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, "isp_GLBL13"
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