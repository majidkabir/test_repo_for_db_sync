SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/***************************************************************************/
/* Store procedure: isp_CtnLabel01                                         */
/* Copyright      : LF Logistics                                           */
/*                                                                         */
/* Date       Rev  Author   Purposes                                       */
/* 2023-04-26 1.0  yeekung  WMS-22237 Created                              */
/* 2023-08-02 1.1  yeekung  WMS23205 Add label requirement (yeekung01)     */
/***************************************************************************/

CREATE   PROC [dbo].[isp_CtnLabel01] (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @cStorerKey       NVARCHAR( 15),
   @cByRef1          NVARCHAR( 20),
   @cByRef2          NVARCHAR( 20),
   @cByRef3          NVARCHAR( 20),
   @cByRef4          NVARCHAR( 20),
   @cByRef5          NVARCHAR( 20),
   @cByRef6          NVARCHAR( 20),
   @cByRef7          NVARCHAR( 20),
   @cByRef8          NVARCHAR( 20),
   @cByRef9          NVARCHAR( 20),
   @cByRef10         NVARCHAR( 20),
   @cPrintTemplate   NVARCHAR( MAX),
   @cPrintData       NVARCHAR( MAX) OUTPUT,
   @nErrNo           INT            OUTPUT,
   @cErrMsg          NVARCHAR( 20)  OUTPUT,
   @cCodePage        NVARCHAR( 50)  OUTPUT
)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cParams1    NVARCHAR( 60)
          ,@cParams2    NVARCHAR( 60)
          ,@cParams3    NVARCHAR( 60)
          ,@cParams4    NVARCHAR( 60)
          ,@cParams5    NVARCHAR( 60)
          ,@cParams6    NVARCHAR( 60)
          ,@cParams7    NVARCHAR( 60)
          ,@cParams8    NVARCHAR( 60)
          ,@cParams9    NVARCHAR( 60)
          ,@cParams10    NVARCHAR( MAX)
          ,@cParams11   NVARCHAR( 60)
          ,@cParams12   NVARCHAR( 4000)
          ,@cParams13   NVARCHAR( 4000)
          ,@cParams14   NVARCHAR( 4000)
          ,@cParams15   NVARCHAR( 4000)
          ,@cParams16   NVARCHAR( 4000)       --yeekung01
          ,@cParams17   NVARCHAR( 4000)       --yeekung01
          ,@cParams18   NVARCHAR( 4000)       --yeekung01
          ,@cParams19   NVARCHAR( 4000)  = ''   --yeekung01
          ,@cParams20   NVARCHAR( 4000)  = ''   --yeekung01
          ,@cParams21   NVARCHAR( 4000)  = ''   --yeekung01
          ,@cParams22   NVARCHAR( 4000)  = ''   --yeekung01
          ,@cParams23   NVARCHAR( 4000)       --yeekung01
          ,@cParams24   NVARCHAR( 4000)       --yeekung01
          ,@cParams25   NVARCHAR( 4000)       --yeekung01
          ,@cParams26   NVARCHAR( 20)       --yeekung01
          ,@cParams27   NVARCHAR( 20)       --yeekung01
          ,@cParams28   NVARCHAR( 20)       --yeekung01
          ,@cParams29   NVARCHAR( 60)       --yeekung01
          ,@cSKUSize    NVARCHAR( 20)         --yeekung01
          ,@cSKUStyle   NVARCHAR( 20)         --yeekung01
          ,@cCounter    NVARCHAR(2) ='1'
          ,@nMaxCount   INT
          ,@cExtraStorer   NVARCHAR(20)
          ,@cBilltoKey  NVARCHAR(20)
          ,@cFacility NVARCHAR(20)

   SET @cPrintData = @cPrintTemplate

   SELECT @cParams1 = UserDefine09,
          @cParams2 = ExternOrderKey,
          @cParams3 = CASE WHEN type = 'B2C' THEN C_contact1 +' ' +C_Company ELSE C_Company END,
          @cExtraStorer = billtokey,
          @cParams12 = buyerPo,
          @cBilltoKey=billtokey
   FROM ORDERS (NOLOCK)
   WHERE ORDERKEY = @cByRef2
      AND Storerkey = @cStorerKey

   SELECT @cFacility = facility
   FROM Rdt.Rdtmobrec (nolock)
   WHERE Mobile = @nMobile



   
   SELECT @cParams4 = SUSR2,
          @cParams5 = CustomerGroupCode,
          @cParams6 = SUSR5,
          @cParams8 = Secondary,
          @cParams9 = SalesChannel
   FROM Storer (NOLOCK)
   WHERE  Storerkey = @cExtraStorer

   DECLARE @nPickQTY int
   DECLARE @nPackQTY INT

   SELECT @nPackQTY = SUM(qty)
   FROM PACKHEADER PH (NOLOCK)
      JOIN PACKDETAIL PD (NOLOCK) ON PH.pickslipno = PD.pickslipno AND PH.storerkey = PD.storerkey
   Where PH.Orderkey = @cByRef2
      AND PD.Storerkey = @cStorerkey

   SELECT @nMaxCount = MAX(cartonno)
   FROM PACKHEADER PH (NOLOCK)
      JOIN PACKDETAIL PD (NOLOCK) ON PH.pickslipno = PD.pickslipno AND PH.storerkey = PD.storerkey
   Where PH.Orderkey = @cByRef2
      AND PD.Storerkey = @cStorerkey


   SELECT @nPickQTY = SUM(qty)
   FROM PICKDetail (NOLOCK)
   Where orderkey = @cByRef2
      AND Storerkey = @cStorerkey
      AND Status <>'4'

   IF @nPickQTY = @nPackQTY 
   BEGIN
      IF @nMaxCount = @cByRef3
      BEGIN
         SET @cParams7 = 'Y'
      END
      ELSE
      BEGIN
         SET @cParams7 = 'N'
      END

      IF EXISTS (SELECT 1
                  FROM Packinfo PI (NOLOCK)
                  WHERE PI.Pickslipno = @cByRef1
                  AND cartonno IN ( SELECT pd.cartonno
                              FROM packdetail PD(NOLOCK)
                              WHERE PD.Pickslipno = PI.Pickslipno
                                 AND PD.Storerkey = @cStorerKey
                                 AND Labelno = @cByRef4)
                  AND refno='Y')
         AND EXISTS (SELECT 1  FROM dbo.Storer WITH (NOLOCK)   
                     WHERE StorerKey = @cBillToKey   
                        AND   Facility = @cFacility   
                        AND   type = '2'   
                        AND   SUSR4 IN ( 'C', 'E', 'Y') ) 

      BEGIN
         SET @cParams26 ='P/L'
      END
      ELSE
      BEGIN
         SET @cParams26 = ''
      END
   END
   ELSE
   BEGIN
      SET @cParams7 = 'N'
      SET @cParams26 = ''
   END

   DECLARE @cSKU NVARCHAR(20)
   DECLARE @cSKUDescr NVARCHAR(20)
   DECLARE @cQTY NVARCHAR(20)

   DECLARE @curPD CURSOR  
   SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT TOP 20 SKU,SUM(qty)
   FROM PACKDETAIL (NOLOCK)
   WHERE Pickslipno = @cByRef1
      AND Storerkey = @cStorerKey
      AND Labelno = @cByRef4
   GROUP BY SKU

     
   OPEN @curPD  
   FETCH NEXT FROM @curPD INTO @cSKU, @cQTY
   WHILE @@FETCH_STATUS = 0  
   BEGIN
      
      SET @cParams10 = @cParams10 + 'SKU' + @cCounter +':' + @cSKU + ' QTY' +':' + @cQTY +  '\& '
      SET @cParams13 = @cParams13 +  @cSKU  +  '\& '

      --(yeekung01)
      SELECT   @cSKUDescr =  SUBSTRING(descr,1,20), 
               @cSKUStyle = Style,
               @cSKUSize  = Size
      FROM SKU SKU (NOLOCK)
      WHERE SKU = @cSKU
         AND Storerkey = @cStorerkey 

      SET @cParams14 = @cParams14  +  @cSKUDescr  +  '\& '
      SET @cParams15 = @cParams15  +  @cQTY  +  '\& '

      

      IF @cCounter <= 10
      BEGIN
         SET @cParams16 = @cParams16  +  @cSKUStyle  +  '\& '
         SET @cParams17 = @cParams17  +  @cSKUSize  +  '\& '
         SET @cParams18 = @cParams18  +  @cQTY  +  '\& '
      END
      ELSE
      BEGIN
         SET @cParams23 = @cParams23  +  @cSKUStyle  +  '\& '
         SET @cParams24 = @cParams24  +  @cSKUSize  +  '\& '
         SET @cParams25 = @cParams25  +  @cQTY  +  '\& '
      END

      SET @cCounter = CAST (@cCounter AS INT) + 1

      FETCH NEXT FROM @curPD INTO @cSKU, @cQTY
   END

   IF @cCounter >  10
   BEGIN
      SELECT @cParams19 = Notes,
             @cParams20 = UDF01,
             @cParams21 = UDF02,
             @cParams22 = UDF03
      FROM CODELKUP (NOLOCK)
      WHERE LISTNAME = 'LVSCUSTL'
         AND Storerkey= @cStorerKey
   END


   SELECT @cParams27 = SUM(QTY)
   FROM PACKDETAIL (NOLOCK)
   WHERE Pickslipno = @cByRef1
      AND Storerkey = @cStorerKey
      AND Labelno = @cByRef4

   SELECT @cParams28 = CAST (SUM(weight)/1000 AS NVARCHAR(20))
   FROM Packinfo PI (NOLOCK)
   WHERE PI.Pickslipno = @cByRef1
      AND cartonno IN ( SELECT pd.cartonno
                  FROM packdetail PD(NOLOCK)
                  WHERE PD.Pickslipno = PI.Pickslipno
                     AND PD.Storerkey = @cStorerKey
                     AND Labelno = @cByRef4)


   IF EXISTS (SELECT 1 FROM CODELKUP (NOLOCK)
              WHERE LISTNAME = 'LVSBCSKIP'
                  AND CODE = @cBilltoKey
                  AND storerkey = @cStorerKey
               )
   BEGIN
      SET @cParams29 = ''
   END
   ELSE
   BEGIN
      SET @cParams29 = '^BY3^BCN,80,N,N^FD' +@cByRef4 +'^FS'
   END

   SET @cParams11 = @cByRef4

   SET @cPrintData = REPLACE (@cPrintData,'<Field01>',RTRIM(ISNULL(@cParams1,'')))
   SET @cPrintData = REPLACE (@cPrintData,'<Field02>',RTRIM(ISNULL(@cParams2,'')))
   SET @cPrintData = REPLACE (@cPrintData,'<Field03>',RTRIM(ISNULL(@cParams3,'')))
   SET @cPrintData = REPLACE (@cPrintData,'<Field04>',RTRIM(ISNULL(@cParams4,'')))
   SET @cPrintData = REPLACE (@cPrintData,'<Field05>',RTRIM(ISNULL(@cParams5,'')))
   SET @cPrintData = REPLACE (@cPrintData,'<Field06>',RTRIM(ISNULL(@cParams6,'')))
   SET @cPrintData = REPLACE (@cPrintData,'<Field07>',RTRIM(ISNULL(@cParams7,'')))
   SET @cPrintData = REPLACE (@cPrintData,'<Field08>',RTRIM(ISNULL(@cParams8,'')))
   SET @cPrintData = REPLACE (@cPrintData,'<Field09>',RTRIM(ISNULL(@cParams9,'')))
   SET @cPrintData = REPLACE (@cPrintData,'<Field10>',RTRIM(ISNULL(@cParams10,'')))
   SET @cPrintData = REPLACE (@cPrintData,'<Field11>',RTRIM(ISNULL(@cParams11,'')))
   SET @cPrintData = REPLACE (@cPrintData,'<Field12>',RTRIM(ISNULL(@cParams12,'')))
   SET @cPrintData = REPLACE (@cPrintData,'<Field13>',RTRIM(ISNULL(@cParams13,'')))
   SET @cPrintData = REPLACE (@cPrintData,'<Field14>',RTRIM(ISNULL(@cParams14,'')))
   SET @cPrintData = REPLACE (@cPrintData,'<Field15>',RTRIM(ISNULL(@cParams15,'')))
   SET @cPrintData = REPLACE (@cPrintData,'<Field16>',RTRIM(ISNULL(@cParams16,'')))
   SET @cPrintData = REPLACE (@cPrintData,'<Field17>',RTRIM(ISNULL(@cParams17,'')))
   SET @cPrintData = REPLACE (@cPrintData,'<Field18>',RTRIM(ISNULL(@cParams18,'')))
   SET @cPrintData = REPLACE (@cPrintData,'<Field19>',RTRIM(ISNULL(@cParams19,'')))
   SET @cPrintData = REPLACE (@cPrintData,'<Field20>',RTRIM(ISNULL(@cParams20,'')))
   SET @cPrintData = REPLACE (@cPrintData,'<Field21>',RTRIM(ISNULL(@cParams21,'')))
   SET @cPrintData = REPLACE (@cPrintData,'<Field22>',RTRIM(ISNULL(@cParams22,'')))
   SET @cPrintData = REPLACE (@cPrintData,'<Field23>',RTRIM(ISNULL(@cParams23,'')))
   SET @cPrintData = REPLACE (@cPrintData,'<Field24>',RTRIM(ISNULL(@cParams24,'')))
   SET @cPrintData = REPLACE (@cPrintData,'<Field25>',RTRIM(ISNULL(@cParams25,'')))
   SET @cPrintData = REPLACE (@cPrintData,'<Field26>',RTRIM(ISNULL(@cParams26,'')))
   SET @cPrintData = REPLACE (@cPrintData,'<Field27>',RTRIM(ISNULL(@cParams27,'')))
   SET @cPrintData = REPLACE (@cPrintData,'<Field28>',RTRIM(ISNULL(@cParams28,'')))
   SET @cPrintData = REPLACE (@cPrintData,'<Field29>',RTRIM(ISNULL(@cParams29,'')))      
          
   SET @cCodePage = '850'                        
                                                 
   GOTO Quit

Quit:

GO