SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: isp_Sku_Log                                         */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Sku column changed log                                      */
/*                                                                      */
/* Called from: ntrSkuUpdate                                            */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 04-Dec-2012 1.1  Leong       SOS# 263375 - Add ProgramName.          */
/************************************************************************/

CREATE PROC [dbo].[isp_Sku_Log] (
   @cStorerKey NVARCHAR(15),
   @cSKU       NVARCHAR(20),
   @cFieldName NVARCHAR(25),
   @cOldValue  NVARCHAR(60),
   @cNewValue  NVARCHAR(60)
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_SPID        Int
         , @c_ProgramName NVARCHAR(100)

   SELECT @n_SPID = @@SPID

   SET @c_ProgramName = ''
   SELECT @c_ProgramName = Program_Name
   FROM master.dbo.Sysprocesses WITH (NOLOCK)
   WHERE SPID = @n_SPID

   INSERT INTO Sku_Log (StorerKey, SKU, FieldName, OldValue, NewValue, ProgramName) -- SOS# 263375
   VALUES (@cStorerKey, @cSKU, @cFieldName, @cOldValue, @cNewValue, @c_ProgramName)

   IF @@ERROR <> 0
      GOTO Quit

Quit:

END

GO