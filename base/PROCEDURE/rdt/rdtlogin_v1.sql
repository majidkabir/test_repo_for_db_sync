SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: rdtLogin_V1                                           */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.3                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver.  Purposes                                  */
/* 2005-11-25   dhung   1.1   Fix ESC key not working on verify storer  */
/*                            and facility screen                       */
/* 2007-08-10   Vicky   1.2   Add Printer Validation & LangCode         */
/* 2007-12-14   Vicky   1.3   SOS#89137 - Check on MultiLogon setting   */
/*                            Y - allow MultiLogon, N - not allow       */
/* 2009-04-08   Vicky   1.4   Disable MultiLogin (Vicky01)              */
/* 2009-10-05   Vicky   1.5   Retire RDTMobRec with Func = 0 (Vicky02)  */
/* 2010-07-22   Vicky   1.6   Add Paper Printer field (Vicky03)         */
/************************************************************************/

CREATE PROC [RDT].[rdtLogin_V1] (
   @nMobile    int,
   @nErrNo     int  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT,
   @nFunction  int OUTPUT
)
AS
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET ANSI_NULLS OFF

   DECLARE @nFunc      int,
          @nScn        int,
          @nStep       int,
          @cUsrName    NVARCHAR(18),
          @cPassword   NVARCHAR(15),
          @cStorer     NVARCHAR(15),
          @cFacility   NVARCHAR(5),
          @cLangCode   NVARCHAR(3),
          @iMenu       int,
          @cMultiLogin NVARCHAR(1),
          @cUsrPasswd  NVARCHAR(15),
          @cDefaultUOM NVARCHAR(10), 
          @bSuccess    int,
          @cPrinter    NVARCHAR(10), -- Added on 10-Aug-2007
          @cPrinter_Paper NVARCHAR(10) -- (Vicky03)

   SELECT @nFunc     = Func,
          @nScn      = Scn,
          @nStep     = Step,
          @cUsrName  = I_Field01,
          @cPassword = I_Field02
   FROM   RDT.RDTMOBREC (NOLOCK)  WHERE Mobile = @nMobile


   IF @nStep = 0
   BEGIN
      IF RTRIM(@cUsrName) IS NULL OR RTRIM(@cUsrName) = ''
      BEGIN
         SELECT @nErrNo = -1,
                @cErrMsg = 'Retrieve Mobile Record Failed, Mobile# ' + RTRIM( CAST(@nMobile as NVARCHAR(3)) )
         GOTO RETURN_SP
      END
   
      SELECT @cStorer     = ISNULL(DefaultStorer, ''),
             @cFacility   = ISNULL(DefaultFacility, ''),
             @cLangCode   = DefaultLangCode, --ISNULL(DefaultLangCode, ''),
             @iMenu       = ISNULL(DefaultMenu, ''),
             @cMultiLogin = ISNULL(MultiLogin, 0),
             @cUsrPasswd  = ISNULL([Password], ''),
             @cDefaultUOM = ISNULL(DefaultUOM, ''),
             @cPrinter    = ISNULL(DefaultPrinter, ''), -- Added on 10-Aug-2007
             @cPrinter_Paper = ISNULL(DefaultPrinter_Paper, '') -- (Vicky03)
      FROM RDT.rdtUser (NOLOCK)
      WHERE Username =  @cUsrname

      IF @@ROWCOUNT = 0 OR (@cUsrPasswd IS NULL) OR (@cUsrPasswd <> @cPassword)
      BEGIN
         SELECT @nErrNo = -1,
            @nStep = 0,
            @cErrMsg = rdt.rdtgetmessage(1,@cLangCode,'DSP')
      END
      ELSE 
      BEGIN
          UPDATE RDT.RDTMOBREC WITH (ROWLOCK)
            SET Lang_Code = CASE WHEN ISNULL(@cLangCode, '') <> '' THEN @cLangCode ELSE 'ENG' END
           WHERE Mobile = @nMobile 
      END

--       IF @cMultiLogin <> 'Y' 
--       BEGIN
-- 	      IF EXISTS (SELECT 1 FROM RDT.RDTMOBREC (NOLOCK) WHERE Username = RTRIM(@cUsrName) AND Step > 0)
-- 	      BEGIN
-- 	         SELECT @nErrNo = -1,
-- 	                @cErrMsg = rdt.rdtgetmessage(44,@cLangCode,'DSP')
-- 	         --GOTO RETURN_SP
-- 	      END
--       END

      -- (Vicky02) - Start     
      IF EXISTS (SELECT 1 FROM RDT.RDTMOBREC (NOLOCK) WHERE Username = RTRIM(@cUsrName) AND Func <= 5 AND Mobile <> @nMobile)
      BEGIN
        UPDATE RDT.RDTMOBREC WITH (ROWLOCK)
         SET Username = 'RETIRED'
        WHERE Username = @cUsrName
        AND Func <= 5 
        AND Mobile <> @nMobile
      END
      -- (Vicky02) - End
      
      -- (Vicky01) - Start     
      IF EXISTS (SELECT 1 FROM RDT.RDTMOBREC (NOLOCK) WHERE Username = RTRIM(@cUsrName) AND Func > 0)
      BEGIN
         SELECT @nErrNo = -1,
                @cErrMsg = rdt.rdtgetmessage(44,@cLangCode,'DSP')
         --GOTO RETURN_SP
      END
      -- (Vicky01) - End


      -- Validate SQL login
      EXECUTE RDT.rdtIsSQLLoginSetup @cUsrName, @cLangCode, @bSuccess OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT
      IF @bSuccess = 0 -- Fail
      BEGIN
         SET @nErrNo = -1
         SET @nStep = 0
      END
   
      IF @nErrNo <> -1
      BEGIN
         -- Update user Last Login data and time
         BEGIN TRAN
   
         Update RDT.rdtUser WITH (ROWLOCK)
          SET LastLogin = GetDate()
         WHERE Username =  @cUsrname
   
         COMMIT TRAN
   
      END
   
      -- Login Successfull update Step
      SELECT @nStep = 1, @nScn = 1
   
      BEGIN TRAN
   
      IF @nErrNo = -1
      BEGIN
         UPDATE RDT.RDTMOBREC WITH (ROWLOCK)
            SET ErrMsg = @cErrMsg
         WHERE Mobile = @nMobile
      END
      ELSE
      BEGIN
         UPDATE RDT.RDTMOBREC WITH (ROWLOCK)
         SET Facility  = @cFacility, StorerKey = @cStorer,    ErrMsg    = @cErrMsg,
         Username  = @cUsrName,      Scn       = @nScn,       Lang_code = @cLangCode,
         O_Field01 = @cStorer ,      O_Field02 = @cFacility,  Step      = @nStep, Func = 1, 
         O_Field03 = CASE @cDefaultUOM WHEN '1' THEN 'Pallet'
                                       WHEN '2' THEN 'Carton'
                                       WHEN '3' THEN 'Inner Pack'
                                       WHEN '4' THEN 'Other Unit 1'
                                       WHEN '5' THEN 'Other Unit 2'
                                       WHEN '6' THEN 'Each'
                                       ELSE 'Each' 
                     END,   
         V_UOM = @cDefaultUOM,
         Printer = @cPrinter, -- Added on 10-Aug-2007  
         O_Field04 = @cPrinter, -- Added on 10-Aug-2007 
         Printer_Paper = @cPrinter_Paper, -- (Vicky03)
         O_Field05 = @cPrinter_Paper -- (Vicky03)
         WHERE Mobile = @nMobile
      END
      IF @@ERROR <> 0
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         COMMIT TRAN
      END
   END
   ELSE IF @nStep = 1
   BEGIN
      -- Do validate Storer
      EXEC rdt.rdtValidateStorernFacility @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT , @nFunction OUTPUT
   END

RETURN_SP:

GO