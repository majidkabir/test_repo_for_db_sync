SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Trigger:  nspDynamicPickCode                                         */
/* Creation Date: 13-May-2008                                           */
/* Copyright: IDS                                                       */
/* Written by: James                                         				*/
/*                                                                      */
/* Purpose:  Gen Dynamic Pick Slip based on the customizable            */
/*           stored proc                                                */
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
/* Date         Who      Purpose                                        */
/************************************************************************/

CREATE PROC [dbo].[nspDynamicPickCode] (
   @c_SPName           NVARCHAR(250),
   @c_WaveKey          NVARCHAR(10),
   @b_Success          int = 1        OUTPUT,
   @n_Err              int = 0        OUTPUT,
   @c_Errmsg           NVARCHAR(250) = '' OUTPUT)
AS 
BEGIN

   SET NOCOUNT ON			-- SQL 2005 Standard
   SET QUOTED_IDENTIFIER OFF	
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF    

   DECLARE @cSQLStatement   nvarchar(2000), 
           @cSQLParms       nvarchar(2000)

   DECLARE @b_debug  int 
   SET @b_debug = 0

   IF @c_SPName = '' OR @c_SPName IS NULL
   BEGIN
      SET @b_Success = 0
      SET @n_Err = 61301    
      SET @c_Errmsg = CONVERT ( NVARCHAR(5), @n_Err) + ' Stored Proc Not Setup. (nspDynamicPickCode)'
      GOTO QUIT
   END
   
   IF EXISTS (SELECT 1 FROM sysobjects WHERE name = dbo.fnc_RTRIM(@c_SPName) AND type = 'P')
   BEGIN

	   SET @cSQLStatement = N'EXEC ' + dbo.fnc_RTRIM(@c_SPName) + 
	       ' @c_Wavekey, @b_Success OUTPUT, @n_Err OUTPUT, @c_Errmsg OUTPUT' 
	
	   SET @cSQLParms = N'@c_Wavekey        NVARCHAR(15),    ' +
                        '@b_Success     int      OUTPUT,  ' +
                        '@n_Err         int      OUTPUT,  ' +
                        '@c_Errmsg      NVARCHAR(250) OUTPUT ' 
	
	   
	   EXEC sp_ExecuteSQL @cSQLStatement, @cSQLParms,    
             @c_Wavekey
            ,@b_Success     OUTPUT
            ,@n_Err         OUTPUT
            ,@c_Errmsg      OUTPUT
   END
QUIT:
END -- procedure


GO