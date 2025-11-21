SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger:  ispGenerateSOfromKit_Wrapper                               */
/* Creation Date: 13-Sep-2006                                           */
/* Copyright: IDS                                                       */
/* Written by: Vicky                                         				*/
/*                                                                      */
/* Purpose:  Generate SO from RCM in KitDetailFrom                      */
/*                                                                      */
/* Output Parameters:  None                                             */
/*                                                                      */
/* PVCS Version: 1.1                                                   	*/
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 08-Dec-2006  Vicky         SOS#63944 - Change the Codelkup Setup     */ 
/*                            New - Code = Storerkey, Short = OrderType */
/*                            Long = Stored Proc                        */
/************************************************************************/

CREATE PROC [dbo].[ispGenerateSOfromKit_Wrapper] (
   @c_StorerKey  NVARCHAR(15), 
   @c_KitKey     NVARCHAR(10),
   @b_Success    int = 1 OUTPUT,
   @n_Err        int = 0 OUTPUT,
   @c_Errmsg     NVARCHAR(250) = '' OUTPUT )
AS 
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   DECLARE 
   @c_ChkGenSOSP    NVARCHAR(250),
   @c_Ordertype     NVARCHAR(10),
   @cSQLStatement   nvarchar(2000), 
   @cSQLParms       nvarchar(2000)  

   SELECT @c_ChkGenSOSP = dbo.fnc_RTrim(Long),
--          @c_Ordertype = dbo.fnc_RTrim(Code)
          @c_Ordertype = dbo.fnc_RTrim(Short)
   FROM   Codelkup (NOLOCK) 
--    WHERE  Short = @c_StorerKey 
   WHERE  Code = @c_StorerKey 
   AND    Listname = 'KIT2SO' 

   IF dbo.fnc_RTrim(@c_ChkGenSOSP) IS NULL OR dbo.fnc_RTrim(@c_ChkGenSOSP) = ''
   BEGIN
      SET @b_Success = -1
      SET @n_Err     = 61566
      SET @c_Errmsg  = 'KIT2SO NOT Setup in CODELKUP Table.' 
      GOTO QUIT 
   END

   SET @cSQLStatement = N'EXEC ' + dbo.fnc_RTrim(@c_ChkGenSOSP) + 
       ' @c_KitKey, @c_Ordertype '

   SET @cSQLParms = N'  @c_KitKey    NVARCHAR(10),
                        @c_Ordertype NVARCHAR(10) '

   
   EXEC sp_ExecuteSQL @cSQLStatement, @cSQLParms,    
          @c_KitKey  
         ,@c_Ordertype 

QUIT:
END -- procedure



GO