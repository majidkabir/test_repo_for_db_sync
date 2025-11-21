SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1667ExtVal01                                          */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 2022-09-20 1.0  James    WMS-20742. Created                                */
/******************************************************************************/

CREATE PROC [RDT].[rdt_1667ExtVal01](
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @nStep          INT,
   @nInputKey      INT,
   @cFacility      NVARCHAR( 5),
   @cStorerKey     NVARCHAR( 15),
   @cPalletKey     NVARCHAR( 20),
   @cOrderKey      NVARCHAR( 10),
   @cCartonId      NVARCHAR( 20),
   @cOption        NVARCHAR( 1),
   @tExtValidVar   VariableTable READONLY,
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE 
    @nNoMixPallet         INT = 0, 
    @nPalletExists        INT = 0,
    @cPalletCriteria      NVARCHAR( 30),
    @cOrdChkField         NVARCHAR( 100),
    @cOrdChkConsignee     NVARCHAR( 100),  
    @cOrdPalletizedField  NVARCHAR( 30) = '', 
    @cPltPalletizedField  NVARCHAR( 30) = '',
    @c_OriExecStatements  NVARCHAR( MAX),
    @c_ExecStatements     NVARCHAR( MAX), 
    @c_ExecArguments      NVARCHAR( MAX)

   DECLARE @cErrMsg1          NVARCHAR( 20),
           @cErrMsg2          NVARCHAR( 20),
           @cErrMsg3          NVARCHAR( 20),
           @cErrMsg4          NVARCHAR( 20),
           @cErrMsg5          NVARCHAR( 20)

   IF @nInputKey = 1 -- Enter
   BEGIN
      IF @nStep = 1 
      BEGIN
      	-- If MBOL exists and it is shipped
      	IF EXISTS ( SELECT 1 FROM dbo.PALLETDETAIL PD WITH (NOLOCK)
                     LEFT JOIN dbo.MBOL M WITH (NOLOCK) ON ( M.ExternMBOLKey = PD.UserDefine03)
                     WHERE PD.PalletKey = @cPalletKey 
                     AND ISNULL(M.MBOLKey, '') <> '')
         BEGIN
            IF EXISTS ( SELECT 1 FROM dbo.PALLETDETAIL PD WITH (NOLOCK)
                        LEFT JOIN dbo.MBOL M WITH (NOLOCK) ON ( M.ExternMBOLKey = PD.UserDefine03)
                        WHERE PD.StorerKey = @cStorerKey 
                        AND PD.PalletKey = @cPalletKey 
                        AND M.Status = '9')
            BEGIN
               SET @nErrNo = 192001
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Mbol Shipped
               GOTO Quit
            END
         END

         IF EXISTS ( SELECT 1   
               FROM dbo.PalletDetail PD WITH (NOLOCK)  
               JOIN dbo.Orders O WITH (NOLOCK) ON ( PD.UserDefine01 = O.OrderKey AND PD.StorerKey = O.StorerKey)   
               LEFT JOIN dbo.Codelkup CL WITH (NOLOCK) ON O.ConsigneeKey = CL.Code AND O.ShipperKey = CL.Code2 AND O.StorerKey = CL.StorerKey AND CL.ListName = 'NOMIXPLSHP'  
               WHERE O.StorerKey = @cStorerKey  
               AND PD.PalletKey = @cPalletKey  
               AND ISNULL( CL.Code, '') <> ''
               AND PD.Status = '9')  
         BEGIN
            SET @nErrNo = 0  
            SET @cErrMsg1 = rdt.rdtgetmessage( 192002, @cLangCode, 'DSP') -- PALLETIZED CUSTOMER
            SET @cErrMsg2 = rdt.rdtgetmessage( 192003, @cLangCode, 'DSP') -- NOT ALLOW TO OPEN
            SET @cErrMsg3 = rdt.rdtgetmessage( 192004, @cLangCode, 'DSP') -- CLOSED PALLET
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
                  @cErrMsg1, @cErrMsg2, @cErrMsg3  
            IF @nErrNo = 1  
            BEGIN  
               SET @cErrMsg1 = ''  
               SET @cErrMsg2 = ''  
               SET @cErrMsg3 = ''  
            END  
               
            SET @nErrNo = 192002
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
            GOTO Quit
         END
      END
   END

Quit:

END

GO