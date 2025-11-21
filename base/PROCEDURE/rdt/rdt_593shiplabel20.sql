SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_593ShipLabel20                                        */
/* Copyright      : Maersk WMS                                                */
/*                                                                            */
/* Purpose: Extended print label                                              */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev    Author     Purposes                                      */
/* 2024-03-13 1.0    Vikas      UWP-15734 Created                             */
/* 2024-10-28 1.1.0  Vikas      UWP-26275 Added UOM display                   */
/******************************************************************************/
CREATE     PROC [RDT].[rdt_593ShipLabel20] (
   @nMobile    INT,
   @nFunc      INT='',
   @nStep      INT='',
   @cLangCode  NVARCHAR( 3)='ENG',
   @cStorerKey NVARCHAR( 15),
   @cOption    NVARCHAR( 1)='',
   @cParam1    NVARCHAR(20),  -- Label No
   @cParam2    NVARCHAR(20)='',
   @cParam3    NVARCHAR(20)='',
   @cParam4    NVARCHAR(20)='',
   @cParam5    NVARCHAR(20)='',
   @nErrNo     INT OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE
      @cFacility        NVARCHAR(  5),
      @cLabelPrinter    NVARCHAR( 10),
      @cPaperPrinter    NVARCHAR( 10),
      @cOrderKey        NVARCHAR( 20),
      @cCustomer        NVARCHAR( 20),
      @cAddress         NVARCHAR( 20),
      @cCity            NVARCHAR( 20),
      @cLoc             NVARCHAR( 20),
      @cSku             NVARCHAR( 20),
      @cQty             NVARCHAR( 30),
      @cQty2             NVARCHAR( 50),
      @cPalletID        NVARCHAR( 20),
      @cShipment        NVARCHAR( 20),
      @nWight           NVARCHAR( 50),
      @cShipLabel       NVARCHAR(10)

   -- Parameter mapping
   SET @cPalletID = @cParam1

   -- Check blank
   IF @cPalletID = ''
   BEGIN
      SET @nErrNo = 227851
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Need DropID
      GOTO Quit
   END

   -- Get login info
   SELECT
      @cFacility = Facility,
      @cLabelPrinter = Printer,
      @cPaperPrinter = Printer_Paper
   FROM rdt.rdtMobrec WITH (NOLOCK)
   WHERE Mobile = @nMobile

   -- Storer configure
   SET @cShipLabel = rdt.rdtGetConfig( @nFunc, 'ShipLabel', @cStorerKey)

   DECLARE cursor_product CURSOR LOCAL FOR

   SELECT ORDERKEY, FINALLOC, SKU, 
      CASE
         WHEN @cStorerKey <>'SABULRPM' THEN CAST(CASECNT AS VARCHAR) +''+' CS'
         WHEN UOM ='LT' THEN CAST(CASECNT/1000 AS VARCHAR) +''+' LT' 
         WHEN UOM ='KG' THEN CAST(CASECNT/1000 AS VARCHAR) +''+' KG'
         WHEN UOM ='MT' THEN CAST(CASECNT/100 AS VARCHAR) +''+' MT'
         WHEN UOM ='PC' THEN CAST(CASECNT AS VARCHAR) +''+' PC'
         WHEN UOM ='G'  THEN CAST(CASECNT/1000 AS VARCHAR) +''+' KG' 
         ELSE CAST(CASECNT AS VARCHAR) 
      END AS QTY,
      CASE 
         WHEN @cStorerKey  NOT IN ('SABULFG', 'SABULRPM') THEN  CAST(SHRCNT AS VARCHAR)+' SHR' 
         ELSE '' 
      END AS QTY2,
      Weight, 
      MBOLKEY 
   FROM (
         SELECT
            O.ORDERKEY,
            TD.FinalLOC,
            ORD.SKU,
            MAX(ORD.UOM)  AS UOM,
            CASE  
               WHEN @cStorerKey <>'SABULRPM' THEN  SUM(PKD.QTY)/MAX(P.CASECNT) 
               ELSE  SUM(PKD.QTY) 
            END AS CASECNT,
            CASE  
               WHEN @cStorerKey <>'SABULRPM' THEN CAST(SUM(PKD.QTY) AS DECIMAL(10,2))% CAST(MAX(P.CASECNT) AS DECIMAL(10,2)) 
               ELSE 0 
            END AS SHRCNT,
            CASE WHEN MAX(S.STDGROSSWGT)>0 THEN (SUM(PKD.QTY)*MAX(S.STDGROSSWGT)/1000) 
               ELSE SUM(PKD.QTY) 
            END Weight,
            MD.MbolKey
         FROM dbo.ORDERS O WITH (NOLOCK) 
         INNER JOIN dbo.ORDERDETAIL ORD WITH (NOLOCK)
            ON ORD.OrderKey=O.OrderKey AND ORD.StorerKey=O.StorerKey
         INNER JOIN dbo.PICKDETAIL PKD WITH (NOLOCK)
            ON PKD.OrderKey=ORD.OrderKey AND PKD.OrderLineNumber=ORD.OrderLineNumber
         INNER JOIN dbo.MBOLDETAIL MD WITH (NOLOCK)
            ON MD.OrderKey=PKD.OrderKey
         INNER JOIN dbo.TASKDETAIL TD WITH (NOLOCK)
            ON TD.TaskDetailKey=PKD.TaskDetailKey
         INNER JOIN dbo.SKU S WITH (NOLOCK)
            ON S.SKU=ORD.SKU AND S.StorerKey=ORD.StorerKey
         INNER JOIN dbo.PACK P WITH (NOLOCK) 
               ON P.PACKKEY=S.PACKKEY 
         WHERE ((PKD.ID= @cPalletID AND (TD.PICKMETHOD='FP' OR TD.PICKMETHOD='PP')) OR ( PKD.DropID= @cPalletID  AND (TD.PICKMETHOD='FP' OR TD.PICKMETHOD='PP')))
            AND PKD.Storerkey= @cStorerKey AND PKD.Status IN (5,9)
         GROUP BY
            O.ORDERKEY,
            ORD.SKU,
            PKD.ID,
            TD.FinalLOC,
            MD.MbolKey
         )t

   IF @@ROWCOUNT = 0
   BEGIN
      SET @nErrNo = 227852
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Invalid DropID
      GOTO Quit
   END

   OPEN cursor_product;

   FETCH NEXT FROM cursor_product INTO
      @cOrderKey,
      @cLoc,
      @cSku,
      @cQty,
      @cQty2,
      @nWight,
      @cShipment;

   WHILE @@FETCH_STATUS = 0
   BEGIN
      DECLARE @tShipLabel AS VariableTable
      INSERT INTO @tShipLabel (Variable, Value) VALUES
      ('@cOrderKey',@cOrderKey),
      ('@cLoc'     ,@cLoc     ),
      ('@cSku'     ,@cSku     ),
      ('@cQty'     ,@cQty     ),
      ('@cQty2'    ,@cQty2    ),
      ('@nWight'   ,@nWight   ),
      ('@cShipment',@cShipment),
      ('@cPalletID',@cPalletID),
      ('@cStorerKey',@cStorerKey)

      -- Print label
      EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter,
           @cShipLabel, -- Report type
           @tShipLabel, -- Report params
           'rdt_593ShipLabel20',
           @nErrNo  OUTPUT,
           @cErrMsg OUTPUT
      DELETE from @tShipLabel
      IF @nErrNo <> 0
         GOTO Quit
      FETCH NEXT FROM cursor_product INTO
         @cOrderKey,
         @cLoc,
         @cSku,
         @cQty,
         @cQty2,
         @nWight,
         @cShipment;
   END;

   CLOSE cursor_product;

   DEALLOCATE cursor_product;
   Quit:
END

GO