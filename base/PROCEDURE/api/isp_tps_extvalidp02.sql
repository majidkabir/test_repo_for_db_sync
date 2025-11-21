SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: isp_TPS_ExtValidP02                                       */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Date         Rev  Author     Purposes                                      */
/* 2022-07-01   1.0  YeeKung  TPS-770 Created                                 */
/******************************************************************************/

CREATE   PROC [API].[isp_TPS_ExtValidP02] (
	@json       NVARCHAR( MAX),
   @jResult    NVARCHAR( MAX) OUTPUT,
   @b_Success  INT = 1        OUTPUT,
   @n_Err      INT = 0        OUTPUT,
   @c_ErrMsg   NVARCHAR( 255) = ''  OUTPUT
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF
BEGIN
	DECLARE
		@cStorerKey   NVARCHAR ( 15),
      @cFacility    NVARCHAR ( 5),
      @nFunc        INT,
      @cBarcode     NVARCHAR( 60),
      @cPreviousBarcode     NVARCHAR( 60),
      @cUserName    NVARCHAR( 30),
      @cLangCode    NVARCHAR( 3),
      @cSKU         NVARCHAR( 30),
      @nLottableQuatity     INT,
      @cPickSlipno   NVARCHAR(20),
      @nPackQTY     INT = 0,
      @cOrderKey     NVARCHAR( 10),
      @cLoadKey      NVARCHAR( 10),
      @cZone         NVARCHAR( 18),
      @cPackByLottable        NVARCHAR(30), 
      @cLottableNum           NVARCHAR(50)

   SET @cPackByLottable = ''  
   EXEC nspGetRight  
         @c_Facility   = @cFacility  
      ,  @c_StorerKey  = @cStorerKey  
      ,  @c_sku        = ''  
      ,  @c_ConfigKey  = 'PackByLottable'  
      ,  @b_Success    = @b_Success       OUTPUT  
      ,  @c_authority  = @cPackByLottable OUTPUT  
      ,  @n_err        = @n_Err           OUTPUT  
      ,  @c_errmsg     = @c_ErrMsg        OUTPUT  
      ,  @c_Option1    = @cLottableNum    OUTPUT  


   CREATE TABLE #PickSKULotatable (  
     StorerKey   NVARCHAR ( 15),
     Facility    NVARCHAR ( 5),
     Func        INT,
     UserName    NVARCHAR( 30),
     LangCode    NVARCHAR( 3),
     Barcode     NVARCHAR( 60),
     LottableQuantity     INT, 
     SKU         NVARCHAR( 30),
      PickSlipno   NVARCHAR(20)
   )

   INSERT INTO #PickSKULotatable  
   SELECT *  
   FROM OPENJSON(@json)  
   WITH (  
     StorerKey   NVARCHAR ( 15) '$.StorerKey',  
     Facility    NVARCHAR ( 5)  '$.Facility',  
     Func        INT            '$.Func',  
     UserName    NVARCHAR( 30)  '$.UserName',  
     LangCode    NVARCHAR( 3)   '$.LangCode',  
     Barcode     NVARCHAR( 60)  '$.Barcode',
     LottableQuantity INT       '$.LottableQuantity',     
     SKU         NVARCHAR( 30)  '$.SKU',    
     Pickslipno  NVARCHAR( 20)  '$.Pickslipno'
   ) 

   SET @b_Success = 1

   select * from #PickSKULotatable

     -- Get PickHeader info
   SELECT TOP 1
      @cOrderKey = OrderKey,
      @cLoadKey = ExternOrderKey,
      @cZone = Zone
   FROM dbo.PickHeader PH WITH (NOLOCK)
   JOIN #PickSKULotatable PK  WITH (ROWLOCK) ON PH.pickheaderkey= PK.pickslipno

   DECLARE PICKLottableCursor CURSOR LOCAL READ_ONLY FAST_FORWARD FOR  
   SELECT PickSlipno,SKU,Barcode,SUM(LottableQuantity),StorerKey
   FROM #PickSKULotatable
   GROUP BY PickSlipno,SKU,Barcode,StorerKey

   OPEN PICKLottableCursor  
   FETCH NEXT FROM PICKLottableCursor INTO @cPickSlipno,@cSku, @cBarcode,@nLottableQuatity,@cStorerKey 
   WHILE @@FETCH_STATUS = 0  
   BEGIN

      IF ISNULL(@cBarcode,'')<>''
      BEGIN
         IF @cPreviousBarcode <> @cBarcode
             SET @nPackQTY = 0

         IF EXISTS (SELECT 1
                    FROM PACKDETAIL (NOLOCK)
                     WHERE Pickslipno = @cPickslipno
                        AND Storerkey = @cStorerKey
                        AND SKU = @cSKU
                        AND lottablevalue = @cBarcode)
         BEGIN
            SELECT @nPackQTY = SUM(qty)
            FROM PACKDETAIL (NOLOCK)
            WHERE Pickslipno = @cPickslipno
               AND Storerkey = @cStorerKey
               AND SKU = @cSKU
               AND lottablevalue = @cBarcode
         END

         SET @nPackQTY = @nPackQTY + @nLottableQuatity

         select @nPackQTY,@nLottableQuatity,@cBarcode

         IF @cOrderKey <> ''
         BEGIN
            IF NOT EXISTS(SELECT 1       
	                  FROM pickDetail PD WITH (NOLOCK)
                     JOIN LOTattribute LOT ON PD.lot=LOT.LOT AND PD.SKU = LOT.SKU
	                  WHERE PD.OrderKey = @cOrderKey
	                     AND PD.Status <= '5'
                        AND PD.Status NOT IN  ('4')
                        AND LOT.lottable02 = @cBarcode
	                  GROUP BY PD.SKU,PD.OrderKey 
                     HAVING SUM(PD.QTY) >= @nPackQTY)  
            BEGIN
         
               SET @n_Err = 1000151      
               SET @c_ErrMsg =API.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')
               SET @jResult = (SELECT '' AS SKU
               FOR JSON PATH,INCLUDE_NULL_VALUES )    
               SET @b_Success = 0
               GOTO QUIT
         
            END

         END
      
         ELSE IF @cLoadKey <> ''
         BEGIN
            IF NOT EXISTS(SELECT 1
	                  FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)
                        JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)
                        JOIN LOTattribute LOT ON PD.lot=LOT.LOT AND PD.SKU = LOT.SKU
	                  WHERE LPD.LoadKey = @cLoadKey
	                     AND PD.Status <= '5'
                        AND PD.Status NOT IN  ('4')
                        AND LOT.lottable02 = @cBarcode
	                  GROUP BY PD.SKU,PD.OrderKey 
                     HAVING SUM(PD.QTY) >= @nPackQTY)  
            BEGIN
         
               SET @n_Err = 1000152      
               SET @c_ErrMsg =API.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')   
               SET @jResult = (SELECT '' AS SKU
               FOR JSON PATH,INCLUDE_NULL_VALUES )    
               SET @b_Success = 0
               GOTO QUIT
         
            END

         END
         ELSE
         BEGIN
            IF NOT EXISTS(SELECT 1
	                  FROM pickDetail PD WITH (NOLOCK)
                        JOIN LOTattribute LOT ON PD.lot=LOT.LOT AND PD.SKU = LOT.SKU
	                  WHERE PD.PickSlipNo = @cPickSlipNo
	                     AND PD.Status <= '5'
                        AND PD.Status NOT IN  ('4')
                        AND LOT.lottable02 = @cBarcode
	                  GROUP BY PD.SKU,PD.OrderKey 
                     HAVING SUM(PD.QTY) >= @nPackQTY)  
            BEGIN
         
               SET @n_Err = 1000153      
               SET @c_ErrMsg =API.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP')   
               SET @jResult = (SELECT '' AS SKU
               FOR JSON PATH,INCLUDE_NULL_VALUES )    
               SET @b_Success = 0
               GOTO QUIT
         
            END

         END
     END
     
      SET @cPreviousBarcode = @cBarcode


      FETCH NEXT FROM PICKLottableCursor INTO @cPickSlipno,@cSku, @cBarcode,@nLottableQuatity,@cStorerKey 
   END

   SET @b_Success = 1
   SET @jResult = (SELECT '' AS SKU
   FOR JSON PATH,INCLUDE_NULL_VALUES )    

QUIT:

END




GO