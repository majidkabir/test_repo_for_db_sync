SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: ispMoveDropIDChkCons                                */
/* Copyright: IDS                                                       */
/* Purpose: Lookup ToLOC                                                */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2012-05-25   Ung       1.0   SOS245688 Check drop ID diff consignee  */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispMoveDropIDChkCons]
   @cLangCode    NVARCHAR( 3), 
   @cFromDropID  NVARCHAR( 20), 
   @cToDropID    NVARCHAR( 20), 
   @cChildID     NVARCHAR( 20), 
   @nErrNo       INT  OUTPUT, 
   @cErrMsg      NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   SET @nErrNo = 0
   SET @cErrMsg = 0
   
   DECLARE @cFromConsigneeKey NVARCHAR( 15)
   DECLARE @cToConsigneeKey   NVARCHAR( 15)
   DECLARE @cDropID           NVARCHAR( 20)
   
   SET @cFromConsigneeKey = ''
   SET @cToConsigneeKey = ''
   SET @cDropID = ''
   
   -- From
   IF ISNULL( @cChildID, '') = ''
      SELECT TOP 1 @cChildID = ChildID FROM dbo.DropIDDetail WITH (NOLOCK) WHERE DropID = @cFromDropID
   
   SELECT TOP 1 @cDropID = DropID FROM dbo.PackDetail WITH (NOLOCK) WHERE @cChildID IN (LabelNo, RefNo2)
   
   SELECT TOP 1 @cFromConsigneeKey = O.ConsigneeKey 
   FROM dbo.Orders O WITH (NOLOCK) 
      JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
   WHERE PD.DropID = @cDropID

   -- To
   SELECT TOP 1 @cChildID = ChildID FROM dbo.DropIDDetail WITH (NOLOCK) WHERE DropID = @cToDropID
   SELECT TOP 1 @cDropID = DropID FROM dbo.PackDetail WITH (NOLOCK) WHERE @cChildID IN (LabelNo, RefNo2)
   SELECT TOP 1 @cToConsigneeKey = O.ConsigneeKey 
   FROM dbo.Orders O WITH (NOLOCK) 
      JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)
   WHERE PD.DropID = @cDropID

   -- Check different consignee
   IF @cFromConsigneeKey <> @cToConsigneeKey
   BEGIN
      SET @nErrNo = 64118
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Consignee Diff
   END
END

GO