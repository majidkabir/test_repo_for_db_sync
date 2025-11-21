SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: rdt_1767ExtInfo02                                   */
/* Copyright      : Maersk                                              */
/*                                                                      */
/* Purpose: Show total ucc scanned fro current user                     */
/*                                                                      */
/* Called from: rdtfnc_TM_CycleCount_UCC                                */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2023-08-03 1.0  James    WMS-23177. Created                          */
/************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_1767ExtInfo02]
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @nStep            INT,
   @nInputKey        INT,
   @cStorerKey       NVARCHAR( 15),
   @cTaskDetailKey   NVARCHAR( 10),
   @cCCKey           NVARCHAR( 10),
   @cCCDetailKey     NVARCHAR( 10),
   @cLoc             NVARCHAR( 10),
   @cID              NVARCHAR( 18),
   @cSKU             NVARCHAR( 20),
   @nActQTY          INT,
   @cLottable01      NVARCHAR( 18),
   @cLottable02      NVARCHAR( 18),
   @cLottable03      NVARCHAR( 18),
   @dLottable04      DATETIME,
   @dLottable05      DATETIME,
   @cLottable06      NVARCHAR( 30),
   @cLottable07      NVARCHAR( 30),
   @cLottable08      NVARCHAR( 30),
   @cLottable09      NVARCHAR( 30),
   @cLottable10      NVARCHAR( 30),
   @cLottable11      NVARCHAR( 30),
   @cLottable12      NVARCHAR( 30),
   @dLottable13      DATETIME,
   @dLottable14      DATETIME,
   @dLottable15      DATETIME,
   @cExtendedInfo    NVARCHAR( 20) OUTPUT

AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cUserName   NVARCHAR( 18)
   DECLARE @nUCC_Count  INT

   SELECT @cUserName = UserName
   FROM rdt.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile
  
   SELECT @nUCC_Count = COUNT( DISTINCT RefNo)
   FROM dbo.CCDetail CC WITH (NOLOCK)
   WHERE CC.Storerkey = @cStorerKey
   AND   Loc = @cLoc
   AND   CC.[Status] IN ( '2', '4')
   AND   CC.EditWho = @cUserName
   AND   EditDate >= CONVERT( DATETIME, DATEDIFF(DAY, 0, GETDATE()))
   AND   ISNULL( RefNo, '') <> ''
   AND   EXISTS ( SELECT 1 
                  FROM dbo.TaskDetail TD WITH (NOLOCK)
                  WHERE CC.CCSheetNo = TD.TaskDetailKey
                  AND   CC.Storerkey = TD.Storerkey
                  AND   TD.TaskType = 'CC')

   SET @cExtendedInfo = 'UCC COUNT: ' + CAST( @nUCC_Count AS NVARCHAR( 5)) 

QUIT:
END -- End Procedure

GO