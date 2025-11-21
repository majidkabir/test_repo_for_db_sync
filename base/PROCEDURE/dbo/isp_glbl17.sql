SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure: isp_GLBL17                                          */
/* Creation Date: 13-May-2019                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-9041 CN BoardRiders Generate label no                   */ 
/*                                                                      */
/* Input Parameters:  @c_PickSlipNo-Pickslipno, @n_CartonNo - CartonNo  */
/*                    Storerconfig: GenLabelNo_SP='isp_GLBL17'          */
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
/************************************************************************/
CREATE PROC [dbo].[isp_GLBL17] ( 
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
           ,@c_Identifier    NVARCHAR(2)
           ,@c_Packtype      NVARCHAR(1)
           ,@c_VAT           NVARCHAR(18)
           ,@nCheckDigit     INT     
           ,@cPackNo_Long    NVARCHAR(250)
           ,@c_Keyname       NVARCHAR(30) 
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
           ,@c_UDF01         NVARCHAR(60)
           ,@c_UDF02         NVARCHAR(60)
           ,@c_UDF03         NVARCHAR(60)
           ,@c_Code          NVARCHAR(30)
           ,@c_TrackingNo    NVARCHAR(60)
           ,@c_OrdTrackingNo NVARCHAR(30)
           ,@n_Findcartonno  INT
           ,@n_CheckDigit    INT
           ,@c_ShipperKey    NVARCHAR(15) = ''
           ,@n_Min           BIGINT
           ,@n_Max           BIGINT
           ,@c_LabelNoRange  NVARCHAR(20)
           ,@n_MaxLen        INT = 9
           ,@b_debug         INT = 0

   SELECT @n_StartTCnt=@@TRANCOUNT, @n_continue=1, @b_success=1, @c_errmsg='', @n_err=0 
   SET @c_LabelNo = ''
   
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      SELECT  @c_ShipperKey = ORDERS.ShipperKey
             ,@c_Storerkey  = ORDERS.Storerkey        
      FROM PICKHEADER (NOLOCK)
      JOIN ORDERS (NOLOCK) ON PICKHEADER.Orderkey = ORDERS.Orderkey
      JOIN CODELKUP (NOLOCK) ON (CODELKUP.LISTNAME = 'BRToll') AND (CODELKUP.CODE = ORDERS.ShipperKey) 
                            AND (CODELKUP.STORERKEY = ORDERS.STORERKEY)
      WHERE PICKHEADER.PickHeaderkey = @c_Pickslipno
      
      IF ISNULL(@c_Storerkey,'') = ''
      BEGIN
         SELECT TOP 1 @c_Storerkey = ORDERS.Storerkey
         FROM PICKHEADER (NOLOCK)
         JOIN ORDERS (NOLOCK) ON PICKHEADER.ExternOrderkey = ORDERS.Loadkey
         WHERE PICKHEADER.PickHeaderkey = @c_Pickslipno
         AND ISNULL(PICKHEADER.ExternOrderkey,'') <> ''
      END
   END

   	 
   IF EXISTS ( SELECT 1 FROM StorerConfig WITH (NOLOCK)
               WHERE StorerKey = @c_StorerKey
               AND ConfigKey = 'GenUCCLabelNoConfig'
               AND SValue = '1') 
   BEGIN
      IF (@c_ShipperKey <> '' OR @c_ShipperKey <> NULL)
      BEGIN
         SET @c_Identifier = '00' --AI Indicator for SSCC
         SET @c_Packtype = '0'    --Extension Digit
         SET @c_LabelNo = ''

         SELECT @c_Packtype = LEFT(RTRIM(ISNULL(CODELKUP.Short,'')),1) --Extension Digit (1 char)
               ,@c_VAT      = ISNULL(CODELKUP.Code2,'')               --GS1 Company Prefix (7 chars)
               ,@n_Min      = CASE WHEN ISNUMERIC(CODELKUP.UDF01) = 1 THEN CAST(CODELKUP.UDF01 AS BIGINT) ELSE 0 END --UDF01 (Min)
               ,@n_Max      = CASE WHEN ISNUMERIC(CODELKUP.UDF02) = 1 THEN CAST(CODELKUP.UDF02 AS BIGINT) ELSE 0 END --UDF02 (Max)
         FROM CODELKUP (NOLOCK)
         WHERE CODELKUP.LISTNAME = 'BRToll' AND CODELKUP.CODE = @c_ShipperKey AND CODELKUP.STORERKEY = @c_Storerkey

         --Check Extension Digit
         IF ISNUMERIC(@c_Packtype) = 0 
         BEGIN
            SELECT @n_Continue = 3         
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38000   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Extension Digit is not a numeric value. (isp_GLBL17)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
            GOTO QUIT_SP
         END 

         --Check GS1 Company Prefix (7 chars)
         IF ISNULL(@c_VAT,'') = ''
            SET @c_VAT = '0000000'

         IF LEN(@c_VAT) <> 7
            SET @c_VAT = RIGHT('0000000' + RTRIM(LTRIM(@c_VAT)), 7)

         IF ISNUMERIC(@c_VAT) = 0 
         BEGIN
            SELECT @n_Continue = 3         
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38010   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': GS1 Company Prefix is not a numeric value. (isp_GLBL17)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
            GOTO QUIT_SP
         END 
      
         IF @n_Max = 0 OR @n_Min > @n_Max
         BEGIN
            SELECT @n_continue = 3  
            SELECT @n_err = 38020   -- Should Be Set To The SQL Errmessage but I don't know how to do so.     
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid Serial Reference no. range setup for shipperkey ''' + RTRIM(@c_Shipperkey) + ''' (isp_GLBL17)' 
            GOTO QUIT_SP
         END

         SET @c_Keyname = 'PackNo_' + LTRIM(RTRIM(@c_ShipperKey))
      
         --Running Number (Serial Reference Unique Number)    
         EXECUTE dbo.nspg_GetKeyMinMax   
					   @c_Keyname,   
					   @n_MaxLen, 
					   @n_Min,
					   @n_Max,
					   @c_LabelNoRange OUTPUT,   
					   @b_Success OUTPUT,   
					   @n_Err OUTPUT,   
					   @c_Errmsg OUTPUT  
         
         SET @c_LabelNo = @c_Identifier + @c_Packtype + RTRIM(@c_VAT) + RTRIM(@c_LabelNoRange) 

         IF @n_continue = 1 OR @n_continue = 2
         BEGIN
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
         END

         SET @c_LabelNo = ISNULL(RTRIM(@c_LabelNo), '') + CAST(@nCheckDigit AS NVARCHAR( 1))
      END
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
   
   IF @b_debug = 1
      SELECT @c_LabelNo

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
      EXECUTE nsp_logerror @n_err, @c_errmsg, "isp_GLBL17"
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