SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_840ExtPackCfm01                                 */  
/* Purpose: Dummy stored proc to skip auto pack confirm                 */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date        Rev  Author     Purposes                                 */  
/* 2021-05-07  1.0  James      WMS-16955. Created                       */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_840ExtPackCfm01] (  
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @nStep            INT,
   @nInputKey        INT,
   @cStorerkey       NVARCHAR( 15),
   @cPickslipno      NVARCHAR( 10),
   @nErrNo           INT           OUTPUT,
   @cErrMsg          NVARCHAR( 20) OUTPUT
)  
AS  
  
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   -- Dummy stored proc to skip auto pack confirm
   -- Pack confirm will happen in this sp: rdt_840ExtUpd13
   Quit:  
  

GO