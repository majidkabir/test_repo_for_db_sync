SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger:  ispLottable02Rule_Wrapper                                  */
/* Creation Date: 22-Sep-2006                                           */
/* Copyright: IDS                                                       */
/* Written by: Vicky                                                    */
/*                                                                      */
/* Purpose:  Generic Lottable02 Rule Wrapper                            */
/*                                                                      */
/* Output Parameters:  None                                             */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* 27-May-2014  TKLIM     1.1   Added Lottables 06-15                   */
/************************************************************************/

CREATE PROC [dbo].[ispLottable02Rule_Wrapper] (
        @c_SPName             NVARCHAR(250)
      , @c_Lottable02Value    NVARCHAR(18)
      , @c_Lottable02Label    NVARCHAR(20)
      , @c_Lottable01         NVARCHAR(18)            OUTPUT
      , @c_Lottable02         NVARCHAR(18)            OUTPUT
      , @c_Lottable03         NVARCHAR(18)            OUTPUT
      , @dt_Lottable04        DATETIME                OUTPUT
      , @dt_Lottable05        DATETIME                OUTPUT
      , @c_Lottable06         NVARCHAR(30)   = ''     OUTPUT
      , @c_Lottable07         NVARCHAR(30)   = ''     OUTPUT
      , @c_Lottable08         NVARCHAR(30)   = ''     OUTPUT
      , @c_Lottable09         NVARCHAR(30)   = ''     OUTPUT
      , @c_Lottable10         NVARCHAR(30)   = ''     OUTPUT
      , @c_Lottable11         NVARCHAR(30)   = ''     OUTPUT
      , @c_Lottable12         NVARCHAR(30)   = ''     OUTPUT
      , @dt_Lottable13        DATETIME       = NULL   OUTPUT
      , @dt_Lottable14        DATETIME       = NULL   OUTPUT
      , @dt_Lottable15        DATETIME       = NULL   OUTPUT
      , @b_Success            int = 1                 OUTPUT
      , @n_Err                int = 0                 OUTPUT
      , @c_Errmsg             NVARCHAR(250)  = ''     OUTPUT )
AS 
BEGIN
   DECLARE @c_ChkGenSOSP    NVARCHAR(250)
         , @c_Ordertype     NVARCHAR(10)
         , @cSQLStatement   NVARCHAR(2000)
         , @cSQLParms       NVARCHAR(2000)  

   IF @c_SPName = '' OR @c_SPName IS NULL
   BEGIN
      SELECT @c_SPName = RTRIM(LONG)
      FROM CODELKUP (NOLOCK)
      WHERE LISTNAME = 'Lottable02'
      AND   CODE = RTRIM(@c_Lottable02Label)   
   END

   IF @c_SPName = '' OR @c_SPName IS NULL
   BEGIN
     GOTO QUIT
   END

   IF EXISTS (SELECT 1 FROM sysobjects WHERE name = RTRIM(@c_SPName) AND type = 'P')
   BEGIN

      SET @cSQLStatement = N'EXEC ' + RTRIM(@c_SPName) + 
                        + ' @c_Lottable02Value, '
                        + ' @c_Lottable01 OUTPUT, @c_Lottable02 OUTPUT, @c_Lottable03 OUTPUT, @dt_Lottable04 OUTPUT, @dt_Lottable05 OUTPUT, '
                        + ' @c_Lottable06 OUTPUT, @c_Lottable07 OUTPUT, @c_Lottable08 OUTPUT, @c_Lottable09 OUTPUT, @c_Lottable10 OUTPUT, '
                        + ' @c_Lottable11 OUTPUT, @c_Lottable12 OUTPUT, @dt_Lottable13 OUTPUT, @dt_Lottable14 OUTPUT, @dt_Lottable15 OUTPUT'
   
      SET @cSQLParms =  N'@c_Lottable02Value NVARCHAR(18)' 
                     + ' ,@c_Lottable01      NVARCHAR(18)   OUTPUT'  
                     + ' ,@c_Lottable02      NVARCHAR(18)   OUTPUT'  
                     + ' ,@c_Lottable03      NVARCHAR(18)   OUTPUT'  
                     + ' ,@dt_Lottable04     NVARCHAR(18)   OUTPUT'  
                     + ' ,@dt_Lottable05     NVARCHAR(18)   OUTPUT' 
                     + ' ,@c_Lottable06      NVARCHAR(30)   OUTPUT'
                     + ' ,@c_Lottable07      NVARCHAR(30)   OUTPUT'
                     + ' ,@c_Lottable08      NVARCHAR(30)   OUTPUT'
                     + ' ,@c_Lottable09      NVARCHAR(30)   OUTPUT'
                     + ' ,@c_Lottable10      NVARCHAR(30)   OUTPUT'
                     + ' ,@c_Lottable11      NVARCHAR(30)   OUTPUT'
                     + ' ,@c_Lottable12      NVARCHAR(30)   OUTPUT'
                     + ' ,@dt_Lottable13     DATETIME       OUTPUT'
                     + ' ,@dt_Lottable14     DATETIME       OUTPUT'
                     + ' ,@dt_Lottable15     DATETIME       OUTPUT'   
      
      EXEC sp_ExecuteSQL @cSQLStatement, @cSQLParms,    
                          @c_Lottable02Value  
                        , @c_Lottable01      OUTPUT
                        , @c_Lottable02      OUTPUT
                        , @c_Lottable03      OUTPUT
                        , @dt_Lottable04     OUTPUT
                        , @dt_Lottable05     OUTPUT
                        , @c_Lottable06      OUTPUT
                        , @c_Lottable07      OUTPUT
                        , @c_Lottable08      OUTPUT
                        , @c_Lottable09      OUTPUT
                        , @c_Lottable10      OUTPUT
                        , @c_Lottable11      OUTPUT
                        , @c_Lottable12      OUTPUT
                        , @dt_Lottable13     OUTPUT
                        , @dt_Lottable14     OUTPUT
                        , @dt_Lottable15     OUTPUT
                        
   END

QUIT:
END -- procedure

GO