SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1867MatrixSP01                                  */
/* Copyright      : Mearsk                                              */
/*                   For HuSq                                           */
/* Date         Rev  Author   Purposes                                  */
/* 2024-10-10   1.0  JHU151    FCR-777 Created                          */ 
/************************************************************************/ 
CREATE   PROC [RDT].[rdt_1867MatrixSP01] (
    @nMobile    INT
   ,@nFunc      INT
   ,@cLangCode  NVARCHAR( 3)
   ,@nStep      INT 
   ,@nInputKey  INT
   ,@cFacility  NVARCHAR( 5)
   ,@cStorerKey NVARCHAR( 15)
   ,@cPickZone  NVARCHAR( 10)
   ,@cCartID    NVARCHAR( 10)  
   ,@cMethod    NVARCHAR( 1)
   ,@cGroupKey  NVARCHAR( 10)
   ,@cResult01  NVARCHAR( 20)  OUTPUT
   ,@cResult02  NVARCHAR( 20)  OUTPUT
   ,@cResult03  NVARCHAR( 20)  OUTPUT
   ,@cResult04  NVARCHAR( 20)  OUTPUT
   ,@cResult05  NVARCHAR( 20)  OUTPUT
   ,@nNextPage  INT = NULL     OUTPUT
   ,@nErrNo     INT            OUTPUT
   ,@cErrMsg    NVARCHAR( 20)  OUTPUT
 )
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @bSuccess          INT
   DECLARE @nPTLKey           BIGINT
   DECLARE @cStation          NVARCHAR(10)
   DECLARE @cIPAddress        NVARCHAR(40)
   DECLARE @cPosition         NVARCHAR(10)
   DECLARE @nCounter          INT
   DECLARE @cQTY              NVARCHAR(20)
   DECLARE @nQTY              INT
   DECLARE @cLightMode        NVARCHAR(4)
   DECLARE @cRow              NVARCHAR(2)
   DECLARE @cDeviceID         NVARCHAR(20)
   DECLARE @cUserName         NVARCHAR(18) 
   DECLARE @cLoc              NVARCHAR(10) 
   DECLARE @nSumqty           INT
   DECLARE @cDeviceIP         NVARCHAR(40)
   DECLARE @nRecOnPage        INT
   DECLARE @nRecCount         INT
   DECLARE @nMaxRecOnPage     INT
   DECLARE @nFirstRecOnPage   INT
   DECLARE @cCartonID         NVARCHAR(20)

   IF @nFunc = 1867
   BEGIN
      IF @nStep IN ('1','2','13')
      BEGIN
         SELECT @cResult03 = COUNT(DISTINCT OrderKey) FROM dbo.TaskDetail WITH(NOLOCK)
         WHERE GroupKey = @cGroupKey
         AND Storerkey = @cStorerKey
         AND DeviceID = @cCartID

         SELECT TOP 1
            @cResult01 = MAX(OrderKey),
            @cResult02 = MAX(Message01)
         FROM dbo.TaskDetail WITH(NOLOCK)
         WHERE Storerkey = @cStorerKey
         AND DeviceID = @cCartID
         AND TaskType = 'ASTCPK'
         AND Status IN ('0','3')
         AND DropID = ''
         AND GroupKey = @cGroupKey
         GROUP BY OrderKey
         ORDER BY OrderKey

         IF @@ROWCOUNT > 0
         BEGIN
            SET @cResult01 = 'OrderKey: ' + @cResult01
            SET @cResult02 = 'BoxType: ' + @cResult02
            SET @cResult03 = 'TotalOrd: ' + @cResult03
         End
         ELSE
         BEGIN
            SET @cResult01 = 'OrderKey: ' 
            SET @cResult02 = 'BoxType: ' 
            SET @cResult03 = 'TotalOrd: ' 
         END

         GOTO Quit
      END
   END
   
Quit:

END




GO