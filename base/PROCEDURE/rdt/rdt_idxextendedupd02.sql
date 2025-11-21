SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_IDXExtendedUpd02                                */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Inditex specific update to LoadPlan                         */
/*                                                                      */
/* Called from:                                                         */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 30-05-2013  1.0  James       Created                                 */
/* 30-07-2013  1.1  James       SOS283551 - If loadplandetail already   */
/*                              update with seq no (userdefine02) then  */
/*                              no need update again (james01)          */
/************************************************************************/

CREATE PROC [RDT].[rdt_IDXExtendedUpd02] (
   @nMobile                   INT,
   @nFunc                     INT, 
   @cLangCode                 NVARCHAR( 3),
   @cStorerkey                NVARCHAR( 15),
   @cWaveKey                  NVARCHAR( 10),
   @cLoadKey                  NVARCHAR( 10),
   @cOtherParm01              NVARCHAR( 20),   
   @cOtherParm02              NVARCHAR( 20),   
   @cOtherParm03              NVARCHAR( 20),   
   @cOtherParm04              NVARCHAR( 20),   
   @cOtherParm05              NVARCHAR( 20),   
   @cOtherParm06              NVARCHAR( 20),   
   @cOtherParm07              NVARCHAR( 20),   
   @cOtherParm08              NVARCHAR( 20),   
   @cOtherParm09              NVARCHAR( 20),   
   @cOtherParm10              NVARCHAR( 20),   
   @bSuccess                  INT               OUTPUT,
   @nErrNo                    INT               OUTPUT,
   @cErrMsg                   NVARCHAR( 20)     OUTPUT   -- screen limitation, 20 NVARCHAR max
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  @nSeq             INT, 
            @cLoadLineNumber  NVARCHAR( 5) 


   IF NOT EXISTS (SELECT 1 FROM dbo.LoadPlan WITH (NOLOCK) 
                  WHERE LoadKey = @cLoadKey
                  AND   Status < '9')
   BEGIN
      SET @nErrNo = 81301  --Invalid LoadKey
      GOTO Quit
   END

   -- If the seq no (userdefine02) is assigned then no need update again
   IF EXISTS (SELECT 1 FROM dbo.LoadPlanDetail WITH (NOLOCK) 
              WHERE LoadKey = @cLoadKey
              AND   ISNULL(UserDefine02, '') <> '')
   BEGIN
      GOTO Quit
   END
   
   SET @nSeq = 1
   
   DECLARE CUR_LOOP CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
   SELECT LoadLineNumber FROM LoadPlanDetail WITH (NOLOCK) 
   WHERE LoadKey = @cLoadKey
   AND   Status < '9'
   ORDER BY OrderKey
   OPEN CUR_LOOP
   FETCH NEXT FROM CUR_LOOP INTO @cLoadLineNumber
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      UPDATE dbo.LoadPlanDetail WITH (ROWLOCK) SET 
         UserDefine02 = CAST(@nSeq AS NVARCHAR( 5)), 
         TrafficCop = NULL 
      WHERE LoadKey = @cLoadKey
      AND   Status < '9'
      AND LoadLineNumber = @cLoadLineNumber

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 81302  --UPD SEQ Fail
         GOTO Quit
      END
      
      -- increase seq no
      SET @nSeq = @nSeq + 1
      
      FETCH NEXT FROM CUR_LOOP INTO @cLoadLineNumber
   END
   CLOSE CUR_LOOP
   DEALLOCATE CUR_LOOP
   
Quit:
               
END

GO