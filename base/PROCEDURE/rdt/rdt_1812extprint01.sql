SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1812ExtPrint01                                  */
/* Purpose: Print label after pallet close, for Unilever                */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2024-03-3 1.0  CYU027      UWP-15734 Created                         */
/************************************************************************/

CREATE   PROC [RDT].[rdt_1812ExtPrint01] (
    @nMobile     INT,
    @nFunc       INT,
    @cLangCode   NVARCHAR( 3),
    @nStep       INT,
    @nInputKey   INT,
    @cStorerkey  NVARCHAR( 15),
    @cOrderKey   NVARCHAR( 10),
    @cPickSlipNo NVARCHAR( 10),
    @cTrackNo    NVARCHAR( 20),
    @cSKU        NVARCHAR( 20),
    @nCartonNo   INT,
    @nErrNo      INT           OUTPUT,
    @cErrMsg     NVARCHAR( 20) OUTPUT
)
AS
BEGIN

    SET NOCOUNT ON
    SET QUOTED_IDENTIFIER OFF
    SET ANSI_NULLS OFF

    DECLARE @cPaperPrinter     NVARCHAR( 10),
        @cLabelPrinter     NVARCHAR( 10),
        @nExpectedQty      INT,
        @nPackedQty        INT,
        @cShipLabel        NVARCHAR( 10),
        @cReturnLabel      NVARCHAR( 10),
        @cPackList         NVARCHAR( 10),
        @cFacility         NVARCHAR( 5),
        @cLoadKey          NVARCHAR( 10),
        @cLabelNo          NVARCHAR( 20)


    IF @nInputKey = 1
    BEGIN
        IF @nStep = 6
        BEGIN
            /*TODO HERE, FINISH THE LOGIC*/
            SET @cPackList = rdt.RDTGetConfig( @nFunc, 'PackList', @cStorerKey)
            IF @cPackList = '0'
                SET @cPackList = ''

            IF @cPackList <> ''
            BEGIN
               DECLARE @tPackList AS VariableTable
               INSERT INTO @tPackList (Variable, Value) VALUES ( '@cLoadKey',     @cLoadKey)
               INSERT INTO @tPackList (Variable, Value) VALUES ( '@cOrderKey',    @cOrderKey)
               INSERT INTO @tPackList (Variable, Value) VALUES ( '@cPickSlipNo',  @cPickSlipNo)

               -- Print label
               EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, '', @cPaperPrinter,
                   @cPackList, -- Report type
                   @tPackList, -- Report params
                   'rdt_1812ExtPrint01',
                   @nErrNo  OUTPUT,
                   @cErrMsg OUTPUT
            END -- Packlist <> ''
        END -- step 6
    END -- inputkey = 1

END -- sp end

SET QUOTED_IDENTIFIER OFF

GO