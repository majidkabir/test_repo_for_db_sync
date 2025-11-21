SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_GenUCCLabelNo_Std                              */
/* Creation Date: 24-Sep-2013                                           */
/* Copyright: LF                                                        */
/* Written by: NJOW                                                     */
/*                                                                      */
/* Purpose: SOS#290121 - Generate UCC Label No (Packing)                */
/*                                                                      */
/* Called By: Scan and Pack                                             */ 
/*                                                                      */
/* Parameters:                                                          */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver.  Purposes                                  */
/* 13-MAY-2016  Wan01   1.1   Add Call CustomSP                         */  
/* 06-JUN-2017  Wan02   1.2   WMS-1816 - CN_DYSON_Exceed_ECOM PACKING   */
/*                            Fixed                                     */  
/************************************************************************/

CREATE PROC [dbo].[isp_GenUCCLabelNo_Std] (
   @cPickslipNo   NVARCHAR(10),
   @nCartonNo     INT            = 0,     --(Wan01)
   @cLabelNo      NVARCHAR(20)   OUTPUT, 
   @b_success     int OUTPUT,
   @n_err         int OUTPUT,
   @c_errmsg      NVARCHAR(225)  OUTPUT
)
AS
BEGIN

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE  @n_Continue INT
         ,  @c_SPCode   NVARCHAR(30)   --(Wan02)

   DECLARE    
   @cIdentifier    NVARCHAR(2),
   @cPacktype      NVARCHAR(1),
   @cVAT           NVARCHAR(18),
   @c_nCounter     NVARCHAR(25),
   @cKeyname       NVARCHAR(30), 
   @cPackNo_Long   NVARCHAR(250),
   @cStorerkey     NVARCHAR(15),
   @nCheckDigit    INT,
   @nTotalCnt      INT,
   @nTotalOddCnt   INT,
   @nTotalEvenCnt  INT,
   @nAdd           INT,
   @nDivide        INT,
   @nRemain        INT,
   @nOddCnt        INT,
   @nEvenCnt       INT,
   @nOdd           INT,
   @nEven          INT

   SELECT @b_success = 1, @c_errmsg='', @n_err=0 

   SET @n_Continue = 1

   SELECT @cStorerkey = ORDERS.Storerkey
   FROM PICKHEADER (NOLOCK)
   JOIN ORDERS (NOLOCK) ON PICKHEADER.Orderkey = ORDERS.Orderkey
   WHERE PICKHEADER.PickHeaderkey = @cPickslipno
   
   IF ISNULL(@cStorerkey,'') = ''
   BEGIN
      SELECT TOP 1 @cStorerkey = ORDERS.Storerkey
      FROM PICKHEADER (NOLOCK)
      JOIN ORDERS (NOLOCK) ON PICKHEADER.ExternOrderkey = ORDERS.Loadkey
      WHERE PICKHEADER.PickHeaderkey = @cPickslipno
      AND ISNULL(PICKHEADER.ExternOrderkey,'') <> ''
   END
   
   --(Wan02) - START
   IF ISNULL(@cStorerkey,'') = ''
   BEGIN
      SELECT TOP 1 @cStorerkey = PACKHEADER.Storerkey
      FROM PACKHEADER (NOLOCK)
      WHERE PACKHEADER.PickSlipNo = @cPickslipno
   END
   --(Wan02) - END

   --(Wan02) - START
   SET @c_SPCode = ''
   SELECT @c_SPCode = ISNULL(RTRIM(sValue),'')
   FROM STORERCONFIG WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
   AND ConfigKey = 'GenLabelNo_SP'

   IF EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@c_SPCode) AND type = 'P')
   BEGIN
      EXEC isp_GenLabelNo_Wrapper
            @c_pickslipno = @cPickslipNo
         ,  @n_cartonno   = @nCartonno
         ,  @c_labelno    = @cLabelNo  OUTPUT

      GOTO QUIT
   END
   --(Wan02) - END

   IF EXISTS ( SELECT 1 FROM StorerConfig WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
               AND ConfigKey = 'GenUCCLabelNoConfig'
               AND SValue = '1')
   BEGIN
      SET @cIdentifier = '00'
      SET @cPacktype = '0'  
      SET @cLabelNo = ''

      SELECT @cVAT = ISNULL(Vat,'')
      FROM Storer WITH (NOLOCK)
      WHERE Storerkey = @cStorerkey
      
      IF ISNULL(@cVAT,'') = ''
         SET @cVAT = '000000000'

      IF LEN(@cVAT) <> 9 
         SET @cVAT = RIGHT('000000000' + RTRIM(LTRIM(@cVAT)), 9)

      --(Wan01) - Fixed if not numeric
      IF ISNUMERIC(@cVAT) = 0 
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 60000
         SET @c_errmsg = 'NSQL ' + CONVERT(NCHAR(5),@n_Err) + ': Vat is not a numeric value. (isp_GenUCCLabelNo_Std)'
         GOTO QUIT
      END 
      --(Wan02) - Fixed if not numeric

      SELECT @cPackNo_Long = Long 
      FROM  CODELKUP (NOLOCK)
      WHERE ListName = 'PACKNO'
      AND Code = @cStorerkey
     
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
         
      SET @cLabelNo = @cIdentifier + @cPacktype + RTRIM(@cVAT) + RTRIM(@c_nCounter) --+ @nCheckDigit

      SET @nOdd = 1
      SET @nOddCnt = 0
      SET @nTotalOddCnt = 0
      SET @nTotalCnt = 0

      WHILE @nOdd <= 20 
      BEGIN
         SET @nOddCnt = CAST(SUBSTRING(@cLabelNo, @nOdd, 1) AS INT)
         SET @nTotalOddCnt = @nTotalOddCnt + @nOddCnt
         SET @nOdd = @nOdd + 2
      END

      SET @nTotalCnt = (@nTotalOddCnt * 3) 
   
      SET @nEven = 2
      SET @nEvenCnt = 0
      SET @nTotalEvenCnt = 0

      WHILE @nEven <= 20 
      BEGIN
         SET @nEvenCnt = CAST(SUBSTRING(@cLabelNo, @nEven, 1) AS INT)
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

      SET @cLabelNo = ISNULL(RTRIM(@cLabelNo), '') + CAST(@nCheckDigit AS NVARCHAR( 1))
   END   -- GenUCCLabelNoConfig
   ELSE
   BEGIN
      EXECUTE nspg_GetKey
         'PACKNO', 
         10 ,
         @cLabelNo   OUTPUT,
         @b_success  OUTPUT,
         @n_err      OUTPUT,
         @c_errmsg   OUTPUT
   END
   Quit:

   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
   END
   ELSE
   BEGIN
      SET @b_Success = 1
   END
END

GO