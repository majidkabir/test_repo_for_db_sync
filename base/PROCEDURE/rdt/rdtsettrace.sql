SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: rdtSetTrace                                        */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 2015-10-06   Ung           Performance tuning for CN Nov 11          */
/************************************************************************/

CREATE PROC [RDT].[rdtSetTrace]
   @inmobile   int ,
   @nFunc      int = 0,
   @nScn       int = 0,
   @nStep      int = 0,
   @StartTime  DATETIME,
   @EndTime    DATETIME,
   @nTimeTaken int = 0, 
   @nScnTime   int = 0
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET ANSI_NULLS OFF

   DECLARE @Func   int
   DECLARE @Scn    int
   DECLARE @Step   int
   DECLARE @Usr    NVARCHAR(18)

   SELECT @Func = Func , @Scn = Scn, @Step = Step , @Usr = Username
   FROM RDT.RDTMOBREC (NOLOCK) WHERE Mobile = @inmobile

   IF @Func IS NOT NULL
      AND @Scn  IS NOT NULL
      AND @Step IS NOT NULL
   BEGIN
      INSERT INTO RDT.RDTTrace(Mobile, InFunc, InScn, InStep, OutFunc, OutScn, OutStep, Usr, StartTime, EndTime, TimeTaken, ScnTime)
      VALUES (@inmobile, @nFunc, @nScn, @nStep, @Func, @Scn, @Step, @Usr, @StartTime, @EndTime, @nTimeTaken, @nScnTime)
   END

END

GO