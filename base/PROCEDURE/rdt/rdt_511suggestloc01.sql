SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*********************************************************************************/
/* Store procedure: rdt_511SuggestLOC01                                          */
/* Copyright      : Maersk WMS                                                   */
/*                                                                               */
/* Date        Rev      Author       Purposes                                    */
/* 2024-03-06  1.0      CYU027       UWP-15739 Created, for Unilever             */
/* 2024-10-28  1.1.0    NLT013       UWP-26270 Fix an issue                      */
/*********************************************************************************/

CREATE   PROC [RDT].[rdt_511SuggestLOC01] (
    @nMobile         INT,
    @nFunc           INT,
    @cLangCode       NVARCHAR( 3),
    @cStorerKey      NVARCHAR( 15),
    @cFacility       NVARCHAR(  5),
    @cFromLOC        NVARCHAR( 10),
    @cFromID         NVARCHAR( 18),
    @cSKU            NVARCHAR( 20),
    @nQTY            INT,
    @cToID           NVARCHAR( 18),
    @cToLOC          NVARCHAR( 10),
    @cType           NVARCHAR( 10),
    @cOutField01     NVARCHAR( 20) OUTPUT,
    @cOutField02     NVARCHAR( 20) OUTPUT,
    @cOutField03     NVARCHAR( 20) OUTPUT,
    @cOutField04     NVARCHAR( 20) OUTPUT,
    @cOutField05     NVARCHAR( 20) OUTPUT,
    @cOutField06     NVARCHAR( 20) OUTPUT,
    @cOutField07     NVARCHAR( 20) OUTPUT,
    @cOutField08     NVARCHAR( 20) OUTPUT,
    @cOutField09     NVARCHAR( 20) OUTPUT,
    @cOutField10     NVARCHAR( 20) OUTPUT,
    @cOutField11     NVARCHAR( 20) OUTPUT,
    @cOutField12     NVARCHAR( 20) OUTPUT,
    @cOutField13     NVARCHAR( 20) OUTPUT,
    @cOutField14     NVARCHAR( 20) OUTPUT,
    @cOutField15     NVARCHAR( 20) OUTPUT,
    @nErrNo          INT           OUTPUT,
    @cErrMsg         NVARCHAR( 20) OUTPUT
)
AS
BEGIN

   DECLARE @toLoc                   NVARCHAR(30) = ''
   DECLARE @cVasLOC                 NVARCHAR(30) = ''
   DECLARE @cLottableNo             NVARCHAR(30) = ''
   DECLARE @cLottableValue          NVARCHAR(30) = ''
   DECLARE @nRowcnt                 INT = 0
   DECLARE @cSQL                    NVARCHAR(MAX)
   DECLARE @cSQLParam               NVARCHAR(MAX)
   DECLARE @cSQLRes                 INT
   DECLARE @t_Subsitute             TABLE
      (  RowID    INT            IDENTITY(1,1)  PRIMARY KEY
         ,Parm     NVARCHAR(100)   NOT NULL DEFAULT('')
      )

   -- Check config exists
   IF rdt.RDTGetConfig( @nFunc, 'DefaultToLoc', @cStorerkey) <> '0'
   BEGIN

      INSERT INTO @t_Subsitute ( Parm )
      SELECT Parm = LTRIM(RTRIM(s.[Value]))
      FROM STRING_SPLIT(rdt.RDTGetConfig( @nFunc, 'DefaultToLoc', @cStorerkey), ',') AS s

      --3 Params in DefaultToLoc
      SELECT @nRowcnt = COUNT(1) FROM @t_Subsitute

      IF @nRowcnt = 3
         BEGIN
            SELECT @cVasLOC = Parm FROM @t_Subsitute WHERE RowID = 1
            SELECT @cLottableNo = Parm FROM @t_Subsitute WHERE RowID = 2
            SELECT @cLottableValue = Parm FROM @t_Subsitute WHERE RowID = 3

            SET @cSQL =
                        'SELECT  @cSQLRes = COUNT(*) '                                                   +
                        'FROM LOTATTRIBUTE LA WITH (NOLOCK) '                                          +
                        'INNER JOIN LotxLocxID LLI WITH (NOLOCK) ON LLI.LOT = LA.LOT '                  +
                        'WHERE LA.StorerKey = @cStorerKey '                                             +
                        'AND LA.SKU = @cSKU '                                                            +
                        'AND LLI.ID = @cFromID '                                                         +
                        'AND LA.Lottable'+@cLottableNo+' = @cLottableValue'

            SET @cSQLParam =
                        '@cStorerKey         NVARCHAR(20),'                +
                        '@cSKU               NVARCHAR(20),'                +
                        '@cFromID            NVARCHAR(20),'                +
                        '@cLottableValue      NVARCHAR(20),'             +
                        '@cSQLRes            INT OUTPUT'

            BEGIN TRY
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                     @cStorerKey, @cSKU, @cFromID, @cLottableValue,@cSQLRes OUTPUT
            END TRY
            BEGIN CATCH
               RETURN
            END CATCH

            IF (@cSQLRes>0)
               SET @toLoc = @cVasLOC
         END

      --1 Param in DefaultToLoc
      IF @nRowcnt = 1
         BEGIN
            --vas location
            SELECT @cVasLOC = Parm FROM @t_Subsitute WHERE RowID = 1
            SET @toLoc = @cVasLOC
         END

      -- Check Default VAS LOC Valid
      IF EXISTS(
         SELECT 1
         FROM LOC WITH (NOLOCK)
         WHERE LocationFlag <> 'DAMAGE'
            AND Facility = @cFacility
            AND Loc = @toLoc
      )
         BEGIN
            SET @cOutField11 = @cVasLOC
         END
   END

END

GO