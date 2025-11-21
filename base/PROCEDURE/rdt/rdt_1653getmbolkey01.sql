SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Store procedure: rdt_1653GetMbolKey01                                */    
/* Copyright      : IDS                                                 */    
/*                                                                      */    
/* Called from: rdtfnc_TrackNo_SortToPallet                             */    
/*                                                                      */    
/* Purpose: Get MBOLKey                                                 */    
/*                                                                      */    
/* Modifications log:                                                   */    
/* Date        Rev  Author   Purposes                                   */    
/* 2020-08-01  1.0  James    WMS-14248. Created                         */  
/* 2021-07-07  1.1  James    WMS-17425 Add Move orders (james01)        */
/* 2021-08-25  1.2  James    WMS-17773 Extend TrackNo to 40 chars       */
/* 2022-03-07  1.3  James    WMS-18350 Filter storer when suggest       */
/*                           palletkey (james02)                        */
/* 2022-09-15  1.3  James    WMS-20667 Add Lane (james02)               */
/************************************************************************/    
    
CREATE PROC [RDT].[rdt_1653GetMbolKey01] (    
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @nStep          INT,
   @nInputKey      INT,
   @cFacility      NVARCHAR( 5),
   @cStorerKey     NVARCHAR( 15),
   @cTrackNo       NVARCHAR( 40),
   @cOrderKey      NVARCHAR( 20),
   @cPalletKey     NVARCHAR( 20) OUTPUT,
   @cMBOLKey       NVARCHAR( 10) OUTPUT,
   @cLane          NVARCHAR( 20) OUTPUT,
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT
) AS    
BEGIN    
   SET NOCOUNT ON    
   SET ANSI_NULLS OFF    
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
   
   DECLARE @cOrderInfo04        NVARCHAR( 30)
   DECLARE @nOrderInfo          INT = 0
   
      -- If it is Sales type order only retrieve based on OrderInfo
      IF EXISTS ( SELECT 1 FROM dbo.CODELKUP C WITH (NOLOCK) 
                  JOIN dbo.Orders O WITH (NOLOCK) ON (C.Code = O.Type AND C.StorerKey = O.StorerKey)
                  WHERE C.ListName = 'HMORDTYPE'
                  AND   C.Short = 'S'
                  AND   O.OrderKey = @cOrderkey
                  AND   O.StorerKey = @cStorerKey)
         SET @nOrderInfo = 1

      IF @nOrderInfo = 0
      BEGIN
         -- Move orders
         IF EXISTS ( SELECT 1 FROM dbo.ORDERS WITH (NOLOCK)
                     WHERE OrderKey = @cOrderkey
                     AND   DocType = 'N'
                     AND   ConsigneeKey LIKE 'W%')
            SET @nOrderInfo = 1
      END

      IF @nOrderInfo = 1
      BEGIN
         SELECT @cOrderInfo04 = OrderInfo04 
         FROM dbo.OrderInfo WITH (NOLOCK)
         WHERE OrderKey = @cOrderKey
      
         SET @cMBOLKey = ''
         SELECT TOP 1 @cMBOLKey = M.MbolKey,
                      @cPalletKey = M.ExternMbolKey 
         FROM dbo.MBOLDETAIL MD WITH (NOLOCK)
         JOIN dbo.MBOL M WITH (NOLOCK) ON ( MD.MbolKey = M.MbolKey)
         JOIN dbo.OrderInfo OI WITH (NOLOCK) ON ( MD.OrderKey = OI.OrderKey)
         JOIN dbo.ORDERS O WITH (NOLOCK) ON ( OI.OrderKey = O.OrderKey)
         WHERE M.[Status] = '0'
         AND   OI.OrderInfo04 = @cOrderInfo04
         AND   O.StorerKey = @cStorerKey
         ORDER BY 1 DESC

         IF EXISTS (SELECT 1 FROM MBOLDETAIL MD WITH (NOLOCK)
                     JOIN dbo.MBOL M WITH (NOLOCK) ON ( MD.MbolKey = M.MbolKey)
                     JOIN dbo.ORDERS O WITH (NOLOCK) ON ( MD.OrderKey = O.OrderKey)
                     WHERE O.storerkey<>@cStorerKey
                     AND M.[Status] = '0'
                     AND MD.mbolkey=@cMBOLKey)
         BEGIN
            SET @cMBOLKey=''
         END

      END
      
Quit:    
END    

GO