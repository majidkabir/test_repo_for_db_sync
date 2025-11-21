SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: rdtPrevScreen                                      */
/* Creation Date: 19-Dec-2004                                           */
/* Copyright: IDS                                                       */
/* Written by: Shong                                                    */
/*                                                                      */
/* Purpose: Go to previous screen when user press Esc key               */
/*                                                                      */
/*                                                                      */
/* Input Parameters: Mobile No                                          */
/*                                                                      */
/* Output Parameters: Screen No                                         */
/*                                                                      */
/* Return Status:                                                       */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/*                                                                      */
/* Called By: rdtHandle                                                 */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 27-Aug-2007  James         Change menu limit from 299 to 499         */
/* 22-Nov-2007  Vicky         Fixes on showing Printer When ESC         */
/* 22-Jul-2010  Vicky         Add Paper Printer field (Vicky01)         */
/* 31-Mar-2011  Ung           SOS210921 Fixes for share menu, session go*/
/*                            back to correct previous menu             */
/* 27-Apr-2011  James         If V_UOM = '' then get rdt user defaultuom*/
/*                            (james01)                                 */
/* 18-Mar-2013  Ung           SOS271056 Add DeviceID                    */
/* 15-Aug-2016  Ung           Update rdtMobRec with EditDate            */
/* 05-Feb-2018  James         WMS3893-Add DefaultDeviceID (james02)     */
/************************************************************************/
CREATE PROC [RDT].[rdtPrevScreen] (
   @nMobile int,
   @nScn    int OUTPUT
) AS
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @nMenu int,
           @cUsername NVARCHAR(15),
           @cPrinter  NVARCHAR(10), -- Added on 22-Nov-2007
           @cPrinter_Paper  NVARCHAR(10), -- (Vicky01)
           @cDeviceID NVARCHAR(20)

   SELECT @nScn = Scn, @nMenu = Menu, @cUsername = Username  
   FROM RDT.RDTMOBREC (NOLOCK) 
   WHERE Mobile = @nMobile

   -- Do nothing when screen
   IF @nScn = 1
   BEGIN
      SET @nScn = 1
   END
   ELSE IF @nScn Between 6 and 499 -- Menu (Screen 5, Mainmenu, do nothing)
   BEGIN
      DECLARE @nDefaultMenu int
      
      SELECT @nDefaultMenu = 0
      
      SELECT @nDefaultMenu = ISNULL(DefaultMenu, 0),
             @cPrinter    = ISNULL(DefaultPrinter, ''), -- Added on 22-Nov-2007  
             @cPrinter_Paper = ISNULL(DefaultPrinter_Paper, ''), -- (Vicky01)
             @cDeviceID = ISNULL(DefaultDeviceID, '')    -- (james02)
      FROM   RDT.rdtUser (NOLOCK)
      WHERE  UserName = @cUserName 
      
      IF @nScn = @nDefaultMenu
      BEGIN
         SET @nScn = 1 
         SET @nMenu = 1 
      
         BEGIN TRAN
         UPDATE MOB WITH (ROWLOCK) SET 
            EditDate = GETDATE(), 
            Scn = @nScn,  Menu = @nMenu,  Func = @nMenu, ErrMsg = '', MenuStack = '', 
               O_Field01 = StorerKey, O_Field02 = Facility, 
               O_Field03 = CASE V_UOM WHEN '1' THEN 'Pallet'
                                      WHEN '2' THEN 'Carton'
                                      WHEN '3' THEN 'Inner Pack'
                                      WHEN '4' THEN 'Other Unit 1'
                                      WHEN '5' THEN 'Other Unit 2'
                                      WHEN '6' THEN 'Each'
--                                      ELSE 'Each' END, -- (james01)
                                      ELSE CASE DefaultUOM WHEN '1' THEN 'Pallet'
                                                           WHEN '2' THEN 'Carton'
                                                           WHEN '3' THEN 'Inner Pack'
                                                           WHEN '4' THEN 'Other Unit 1'
                                                           WHEN '5' THEN 'Other Unit 2'
                                                           WHEN '6' THEN 'Each'
                                                           ELSE 'Each' END
                                           END,
               O_Field04  = @cPrinter, -- Added on 22-Nov-2007    
               O_Field05  = @cPrinter_Paper, -- (Vicky01) 
               O_Field06  = @cDeviceID
         FROM rdt.rdtMobRec MOB 
         JOIN rdt.rdtUser RDTUSER WITH (NOLOCK) ON MOB.UserName = RDTUSER.UserName
         WHERE MOBILE = @nMobile
         COMMIT TRAN
         RETURN 
      END
      ELSE
      BEGIN
         -- Get Parent Menu
         SELECT @nScn = RIGHT( MenuStack, 3) 
         FROM RDT.rdtMobRec WITH (NOLOCK)
         WHERE Mobile = @nMobile

         -- Remove parent menu from menu stack
         UPDATE RDT.rdtMobRec WITH (ROWLOCK) SET
            EditDate = GETDATE(), 
            MenuStack = LEFT( MenuStack, ABS( LEN( MenuStack) - 3))
         WHERE Mobile = @nMobile

         SET @nMenu = @nScn
      END 
   END
   ELSE IF @nScn between 500 and 899
   BEGIN
      SET @nScn = @nMenu
   END

   BEGIN TRAN
      UPDATE RDT.RDTMOBREC WITH (ROWLOCK) SET 
         EditDate = GETDATE(), 
         Scn = @nScn,
         Menu = @nMenu,
         Func = @nMenu,
         ErrMsg = ''
      WHERE MOBILE = @nMobile
   COMMIT TRAN

GO