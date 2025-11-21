SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Stored Procedure: rdtProcessMenu                                           */
/* Creation Date: 19-Dec-2004                                                 */
/* Copyright: IDS                                                             */
/* Written by: Shong                                                          */
/*                                                                            */
/* Purpose: Set next screen or Menu when user enter the option in             */
/*          menu screen.                                                      */
/*                                                                            */
/* Input Parameters: Mobile No                                                */
/*                                                                            */
/* Output Parameters: Error No and Error Message                              */
/*                                                                            */
/* Return Status:                                                             */
/*                                                                            */
/* Usage:                                                                     */
/*                                                                            */
/*                                                                            */
/* Called By: rdtHandle                                                       */
/*                                                                            */
/* PVCS Version: 1.3                                                          */
/*                                                                            */
/* Version: 5.4                                                               */
/*                                                                            */
/* Data Modifications:                                                        */
/*                                                                            */
/* Updates:                                                                   */
/* Date         Author        Purposes                                        */
/* 27-Aug-2007  James         Change menu limit from 299 to 499               */
/* 31-Mar-2011  Ung           SOS210921 Fixes for share menu, session go      */
/*                            back to correct previous menu                   */
/* 11-Jan-2012  Leong         SOS# 233768 - Reset screen variables            */
/* 22-May-2012  Ung           SOS245172 Fix field attr not reset (ung01)      */
/* 24-Jan-2014  ChewKP        Clear Off InField and OutField when             */
/*                            entering new module (ChewKP01)                  */
/* 23-Mar-2015  Ung           Clear InField06                                 */
/* 18-May-2015  Ung           SOS286143 Fix runtime error if SP not found     */
/* 05-Aug-2015  Ung           Support storer group                            */
/* 15-aug-2016  Ung           Update rdtMobRec with EditDate                  */
/* 25-Nov-2016  James         Add menu 7-9 (james01)                          */
/* 01-Mar-2018  James         Support multi language (james02)                */
/* 25-Sep-2018  Ung           WMS-6410 Add field 16-20                        */
/******************************************************************************/

CREATE PROC [RDT].[rdtProcessMenu] (
   @nMobile    int,
   @nErrNo     int           OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT ,
   @nFunction  int           OUTPUT
)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nOption  int,
           @nSubMenu int,
           @nMenu    int,
           @cLang_Code  NVARCHAR( 3)   -- (james02)

   SELECT @nErrNo = 0

   SELECT @nOption = cast(CASE I_Field01
             WHEN '1' THEN 1
             WHEN '2' THEN 2
             WHEN '3' THEN 3
             WHEN '4' THEN 4
             WHEN '5' THEN 5
             WHEN '6' THEN 6
             WHEN '7' THEN 7
             WHEN '8' THEN 8
             WHEN '9' THEN 9
             ELSE 0
             END AS int),
          @nMenu   = Menu,
          @cLang_Code = Lang_Code
   FROM   RDT.RDTMOBREC (NOLOCK)  WHERE  Mobile = @nMobile



   IF @nOption BETWEEN 1 and 9
   BEGIN
      SELECT @nSubMenu = CASE @nOption
             WHEN 1 THEN OP1
             WHEN 2 THEN OP2
             WHEN 3 THEN OP3
             WHEN 4 THEN OP4
             WHEN 5 THEN OP5
             WHEN 6 THEN OP6
             WHEN 7 THEN OP7
             WHEN 8 THEN OP8
             WHEN 9 THEN OP9
             END
      FROM RDT.rdtMenu (NOLOCK) WHERE MenuNo = @nMenu

      IF @nSubMenu = 0 OR @nSubMenu IS NULL
      BEGIN
         SELECT @nErrNo = -1
         SELECT @cErrMsg = rdt.rdtgetmessage(4,@cLang_Code,'DSP')
      END
      ELSE
      BEGIN
         -- Check if reach max menu level
         IF (SELECT LEN( MenuStack) FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile) = 60
         BEGIN
            SELECT @nErrNo = -1
            SELECT @cErrMsg = rdt.rdtgetmessage(51,@cLang_Code,'DSP') --51^MaxMenuLevel
            GOTO Fail
         END
         
         -- Check SP defined
         IF @nSubMenu >= 500
         BEGIN 
            -- Get SP
            DECLARE @cStoredProcName SYSNAME
            SELECT @cStoredProcName = StoredProcName 
            FROM rdt.rdtMsg WITH (NOLOCK) 
            WHERE Message_ID = @nSubMenu 
               AND Message_Type = 'FNC'
            
            -- Check SP valid
            IF NOT EXISTS( SELECT 1 FROM sys.sysobjects WHERE name = @cStoredProcName AND Type = 'P')
            BEGIN
               SELECT @nErrNo = -1
               SELECT @cErrMsg = '53^SPNotExist(' + RTRIM( CAST( @nSubMenu AS NVARCHAR(5))) + ')'
               GOTO Fail
            END
         END

         SET @nFunction = @nSubMenu

         UPDATE RDT.RDTMOBREC WITH (ROWLOCK) SET 
              EditDate = GETDATE(), 
              Scn  = @nSubMenu,
              Func = @nFunction,
              Menu = CASE WHEN @nSubMenu between 5 and 499
                          THEN @nSubMenu
                          ELSE ISNULL(Menu, 0)
                     END,
              MenuStack = CASE WHEN @nSubMenu between 5 and 499
                               THEN MenuStack + RIGHT( '000' + CAST( @nMenu AS NVARCHAR( 3)), 3) -- Store current menu into menu stack
                               ELSE ISNULL(MenuStack, 0)
                          END,
              ErrMsg = '', 
              V_StorerKey = ISNULL( StorerKey, ''), -- Copy default storer to session storer
              I_Field01 = '',  O_Field01 = '',  FieldAttr01 = '', 
              I_Field02 = '',  O_Field02 = '',  FieldAttr02 = '', 
              I_Field03 = '',  O_Field03 = '',  FieldAttr03 = '', 
              I_Field04 = '',  O_Field04 = '',  FieldAttr04 = '', 
              I_Field05 = '',  O_Field05 = '',  FieldAttr05 = '', 
              I_Field06 = '',  O_Field06 = '',  FieldAttr06 = '', 
              I_Field07 = '',  O_Field07 = '',  FieldAttr07 = '', 
              I_Field08 = '',  O_Field08 = '',  FieldAttr08 = '', 
              I_Field09 = '',  O_Field09 = '',  FieldAttr09 = '', 
              I_Field10 = '',  O_Field10 = '',  FieldAttr10 = '', 
              I_Field11 = '',  O_Field11 = '',  FieldAttr11 = '', 
              I_Field12 = '',  O_Field12 = '',  FieldAttr12 = '', 
              I_Field13 = '',  O_Field13 = '',  FieldAttr13 = '', 
              I_Field14 = '',  O_Field14 = '',  FieldAttr14 = '', 
              I_Field15 = '',  O_Field15 = '',  FieldAttr15 = '',  
              I_Field16 = '',  O_Field16 = '',  FieldAttr16 = '', 
              I_Field17 = '',  O_Field17 = '',  FieldAttr17 = '', 
              I_Field18 = '',  O_Field18 = '',  FieldAttr18 = '', 
              I_Field19 = '',  O_Field19 = '',  FieldAttr19 = '', 
              I_Field20 = '',  O_Field20 = '',  FieldAttr20 = ''  
         WHERE Mobile = @nMobile
/*
         --(ung01) 
         IF @nFunction >= 500
            UPDATE RDT.RDTMOBREC WITH (ROWLOCK) SET
                 FieldAttr01 = '', FieldAttr02 = '', FieldAttr03 = '', FieldAttr04 = '', FieldAttr05 = '', 
                 FieldAttr06 = '', FieldAttr07 = '', FieldAttr08 = '', FieldAttr09 = '', FieldAttr10 = '', 
                 FieldAttr11 = '', FieldAttr12 = '', FieldAttr13 = '', FieldAttr14 = '', FieldAttr15 = ''  
            WHERE Mobile = @nMobile
*/
      END
   END
   ELSE -- Not 1 to 6
   BEGIN
      SELECT @nErrNo = -1
      IF @nOption = 0
         SELECT @cErrMsg = rdt.rdtgetmessage(4,@cLang_Code,'DSP')
   END

Fail:
   IF @nErrNo = -1
   BEGIN
      BEGIN TRAN
         UPDATE RDT.RDTMOBREC WITH (ROWLOCK) SET 
            EditDate = GETDATE(), 
            ErrMsg = @cErrMsg 
         WHERE Mobile = @nMobile
      COMMIT TRAN
   END

GO