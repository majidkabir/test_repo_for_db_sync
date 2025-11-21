SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_GenerateUPI                                    */
/* Creation Date: 14-Jun-2010                                           */
/* Copyright: IDS                                                       */
/* Written by: LIM KAH HWEE                                             */
/*                                                                      */
/* Purpose: Generate HDNL Unique Parcel Identifier for barcode purposes */
/*                                                                      */
/*                                                                      */
/* Called By: RDT.rdt_EcommDispatch_Confirm                             */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author Ver Purposes                                      */
/* 2010-07-28  KHLim  1.0 add a leading zero if depot number is single digit */
/* 2010-07-28  KHLim  1.1 rectify coding for error handling             */
/* 2010-07-29  KHLim  1.2 add grant execute to NSQL                     */
/* 2010-08-05  KHLim  1.3 change parameter & get TAC fr CODELKUP (KHLim01)*/
/*                        change nSector to cSector CHAR(1)             */
/* 2010-08-05  KHLim  1.4 add validation (KHLim02)                      */
/************************************************************************/

CREATE PROC [dbo].[isp_GenerateUPI]      
(
  @nPack     int,
--  @cPostcode NVARCHAR(12), (KHLim01)
  @cOrderKey NVARCHAR(10),   -- (KHLim01)
  @cUPI      NVARCHAR(16) OUTPUT,
  @nErrNo    int OUTPUT,
  @cErrMsg   NVARCHAR(20) OUTPUT
)
AS
BEGIN

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS ON
SET CONCAT_NULL_YIELDS_NULL OFF
    
   DECLARE @nPackCnt   NVARCHAR(1),
           @cPostcode  NVARCHAR(12),  -- (KHLim01)
           @cCleanPC   NVARCHAR(12),
           @cTAC       NVARCHAR(3),
           @nDepot     int,
           @nConUniNo  int,
           @i          int,
           @pi         int,
           @cSQL       nvarchar(MAX),
           @cIncoTerm  NVARCHAR(10)

   DECLARE @b_success  int,
           @cLangCode  NVARCHAR(3),
           @n_continue int

   SELECT @n_continue=1, @b_success=0, @nErrNo=0, @cErrMsg=''

   EXECUTE nspg_getkey
               "ConUniNo"
               , 10
               , @nConUniNo OUTPUT
               , @b_success OUTPUT
               , @nErrNo OUTPUT
               , @cErrMsg OUTPUT

   IF @nPack >= 1 AND @nPack <= 20
   BEGIN
      SET @nPackCnt = CASE @nPack
                        WHEN  1 THEN 'A'
                        WHEN  2 THEN 'B'
                        WHEN  3 THEN 'C'
                        WHEN  4 THEN 'D'
                        WHEN  5 THEN 'E'
                        WHEN  6 THEN 'F'
                        WHEN  7 THEN 'G'
                        WHEN  8 THEN 'H'
                        WHEN  9 THEN 'J'
                        WHEN 10 THEN 'K'
                        WHEN 11 THEN 'L'
                        WHEN 12 THEN 'M'
                        WHEN 13 THEN 'N'
                        WHEN 14 THEN 'P'
                        WHEN 15 THEN 'R'
                        WHEN 16 THEN 'T'
                        WHEN 17 THEN 'V'
                        WHEN 18 THEN 'W'
                        WHEN 19 THEN 'X'
                        WHEN 20 THEN 'Y'
                    END
   END
   ELSE
   BEGIN
      SET @n_continue = 3
      SET @nErrNo = 70616
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidPackCnt
      GOTO Quit_SP
   END

   SELECT @cPostCode = ISNULL(RTRIM(C_ZIP),   ''),
          @cIncoTerm = ISNULL(RTRIM(IncoTerm),'')
   FROM  ORDERS WITH (NOLOCK)  
   WHERE Orderkey = @cOrderkey  

   SET @cCleanPC = ''
   SET @pi = 1
   WHILE @pi <= LEN(@cPostcode)
   BEGIN
      SET @i = 48 -- NVARCHAR(48) = 0
      WHILE @i < 123 -- NVARCHAR(122) = z
      BEGIN
         IF (@i > 47 AND @i < 58) OR (@i > 64 AND @i < 91) -- OR (@i > 96 AND @i < 123)    no need to check uppercase as not case-sensitive
            IF SUBSTRING(@cPostcode, @pi, 1) = master.dbo.fnc_GetCharASCII(@i)
               SET @cCleanPC = @cCleanPC + SUBSTRING(@cPostcode, @pi, 1)
         SET @i = @i + 1
      END
      SET @pi = @pi + 1
   END

   DECLARE @SecStr    NVARCHAR(5),
           @cArea     NVARCHAR(3),
           @nDistrict NVARCHAR(2),
           @cSector   NVARCHAR(1),  -- (KHLim01)
           @cUnit     NVARCHAR(2)
   IF ISNUMERIC(SUBSTRING(@cCleanPC,2,1)) = 1
   BEGIN -- A#
      SET @cArea = LEFT(@cCleanPC,1)
      IF ISNUMERIC(SUBSTRING(@cCleanPC,3,1)) = 1
      BEGIN -- A##
         IF ISNUMERIC(SUBSTRING(@cCleanPC,4,1)) = 1
            SET @SecStr = 'A###A'
         ELSE
            SET @SecStr = 'A##AA'
      END
      ELSE
      BEGIN -- A#A
         SET @SecStr = 'A#A#A'
      END
   END
   ELSE
   BEGIN -- AA
      IF ISNUMERIC(SUBSTRING(@cCleanPC,3,1)) = 1
      BEGIN -- AA#
         SET @cArea = LEFT(@cCleanPC,2)
         IF ISNUMERIC(SUBSTRING(@cCleanPC,4,1)) = 1
         BEGIN -- AA##
            IF ISNUMERIC(SUBSTRING(@cCleanPC,5,1)) = 1
               SET @SecStr = 'AA###'
            ELSE
               SET @SecStr = 'AA##A'
         END
         ELSE
         BEGIN -- AA#A
           SET @SecStr = 'AA#A#'
         END
      END
      ELSE
      BEGIN -- AAA
         SET @cArea = LEFT(@cCleanPC,3)
         SET @SecStr = 'AAA#A'
      END
      
   END


   IF      @SecStr = 'A##AA'
   BEGIN
      SET @nDistrict = SUBSTRING(@cCleanPC,2,1)
      SET @cSector   = SUBSTRING(@cCleanPC,3,1)
   END
   ELSE IF @SecStr = 'A###A'
   BEGIN
      SET @nDistrict = SUBSTRING(@cCleanPC,2,2)
      SET @cSector   = SUBSTRING(@cCleanPC,4,1)
   END
   ELSE IF @SecStr = 'A#A#A'
   BEGIN
      SET @nDistrict = SUBSTRING(@cCleanPC,2,2)
      SET @cSector   = SUBSTRING(@cCleanPC,4,1)
   END
   ELSE IF @SecStr = 'AA##A'
   BEGIN
      SET @nDistrict = SUBSTRING(@cCleanPC,3,1)
      SET @cSector   = SUBSTRING(@cCleanPC,4,1)
   END
   ELSE IF @SecStr = 'AA###'
   BEGIN
      SET @nDistrict = SUBSTRING(@cCleanPC,3,2)
      SET @cSector   = SUBSTRING(@cCleanPC,5,1)
   END
   ELSE IF @SecStr = 'AA#A#'
   BEGIN
      SET @nDistrict = SUBSTRING(@cCleanPC,3,2)
      SET @cSector   = SUBSTRING(@cCleanPC,5,1)
   END
   ELSE IF @SecStr = 'AAA#A'
   BEGIN
      SET @nDistrict = ''
      SET @cSector   = SUBSTRING(@cCleanPC,4,1)
   END

   IF LEN(@cCleanPC) < 8
      SET @cUnit = RIGHT(@cCleanPC,2)
   ELSE IF @SecStr = 'A##AA'
      SET @cUnit = SUBSTRING(@cCleanPC,4,2)
   ELSE IF RIGHT(@SecStr,1) = 'A'
      SET @cUnit = SUBSTRING(@cCleanPC,5,2)
   ELSE IF RIGHT(@SecStr,1) = '#'
      SET @cUnit = SUBSTRING(@cCleanPC,6,2)

   SELECT @cTAC = LEFT(Long,3)  -- (KHLim01)
   FROM dbo.Codelkup WITH (NOLOCK) 
   WHERE Listname = 'HDNTERMS'
   AND   Code     = @cIncoTerm

   IF @@ROWCOUNT = 0 OR LEN(@cTAC) = 0  -- (KHLim02)
   BEGIN
      SET @cTAC = '   '
   END
   ELSE IF LEN(@cTAC) = 2
   BEGIN
      SET @cTAC = @cTAC + ' '
   END
   ELSE IF LEN(@cTAC) = 1
   BEGIN
      SET @cTAC = @cTAC + '  '
   END

--   SET @cSQL = 'SELECT TOP 1 Depot FROM DTSITF.dbo.REPHDNRoute' +
--   ' WHERE Area              =''' + @cArea + '''' +
--   '   AND DC                =''' + @nDistrict + '''' +
--   '   AND DepartmentSection =''' + @cSector + '''' +
--   '   AND UnitLow          <=''' + @cUnit + '''' +
--   '   AND UnitHigh         >=''' + @cUnit + ''''
--   PRINT @cSQL
--   EXEC sp_ExecuteSql @cSQL


   SET ROWCOUNT 1
   SELECT @nDepot=Depot FROM dbo.REPHDNRoute
   WHERE Area              = @cArea
     AND DC                = @nDistrict
     AND DepartmentSection = @cSector
     AND UnitLow          <= @cUnit
     AND UnitHigh         >= @cUnit
   IF @@ROWCOUNT = 0
   BEGIN
      SELECT @nDepot=Depot FROM dbo.REPHDNRoute
      WHERE Area              = @cArea
        AND DC                = @nDistrict
        AND DepartmentSection = @cSector
      IF @@ROWCOUNT = 0
      BEGIN
         SELECT @nDepot=Depot FROM dbo.REPHDNRoute
         WHERE Area              = 'ZY'
           AND DC                = '99'
           AND DepartmentSection = '9'
           AND UnitLow           = 'AA'
         IF @@ROWCOUNT = 0
         BEGIN
            
               SET @nDepot = '00' -- one man product
            
                --  SET @nDepot = '87'  for two man product

         END
      END
   END
   SET ROWCOUNT 0


   Quit_SP:  
   IF @n_continue = 3  -- Error Occured
   BEGIN 
      EXECUTE nsp_logerror @nErrNo, @cErrMsg, 'isp_GenerateUPI'
--      RAISERROR (@cErrMsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN -- (KHLim01)
      SET @cUPI = '8' + @cTAC + CAST(REPLACE(STR(@nConUniNo,8),' ','0') AS NVARCHAR(8)) + @nPackCnt + 
                  '0'         + CAST(REPLACE(STR(@nDepot   ,2),' ','0') AS NVARCHAR(2))
   END

END -- procedure

GO