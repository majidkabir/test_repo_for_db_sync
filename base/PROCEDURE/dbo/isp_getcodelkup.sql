SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/
/* Object Name: isp_GetCodeLkup                                            */
/* Modification History:                                                   */
/*                                                                         */
/* Called By:  Exceed                                                      */
/*                                                                         */
/* PVCS Version: 1.0                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Date         Author    Ver.  Purposes                                   */
/* 2018-08-06   KHLim     1.0   Initial revision                           */
/***************************************************************************/
CREATE PROC [dbo].[isp_GetCodeLkup] 
  @LISTNAME nvarchar(30)
, @StorerKey nvarchar(15)
, @Code nvarchar(30)
, @code2 nvarchar(30)
, @ErrMsg nvarchar(250) = '' OUTPUT
, @Err int = 0 OUTPUT
, @Description nvarchar(250) OUTPUT
, @Short nvarchar(10) = '' OUTPUT
, @Long nvarchar(250) = '' OUTPUT
, @Notes nvarchar(4000) = '' OUTPUT
, @Notes2 nvarchar(4000) = '' OUTPUT
, @UDF01 nvarchar(60) = '' OUTPUT
, @UDF02 nvarchar(60) = '' OUTPUT
, @UDF03 nvarchar(60) = '' OUTPUT
, @UDF04 nvarchar(60) = '' OUTPUT
, @UDF05 nvarchar(60) = '' OUTPUT
AS
BEGIN
   SET NOCOUNT ON;
   SET ANSI_NULLS OFF;
   SET QUOTED_IDENTIFIER OFF;
   SET CONCAT_NULL_YIELDS_NULL OFF;

   DECLARE @Proc nvarchar(128),
           @Start datetime,
           @Duration int,
           @Stmt nvarchar(max)
   --BEGIN TRY
   SELECT TOP 1
      @LISTNAME = LISTNAME,
      @Code = Code,
      @Description = [Description],
      @Short = Short,
      @Long = Long,
      @Notes = Notes,
      @Notes2 = Notes2,
      @Storerkey = Storerkey,
      @UDF01 = UDF01,
      @UDF02 = UDF02,
      @UDF03 = UDF03,
      @UDF04 = UDF04,
      @UDF05 = UDF05
   FROM CODELKUP WITH (NOLOCK)
   WHERE Code = @Code
   AND Listname = @LISTNAME
   AND code2 = @code2
   AND StorerKey = @StorerKey
   ORDER BY EditDate DESC

   --END TRY
   --BEGIN CATCH
   --EXEC dbo.ispLogError @DB, @Schema, @Proc, @Id, @ErrMsg OUTPUT, @Err OUTPUT, @Success OUTPUT
   --END CATCH
   --SET @Duration = DATEDIFF(s,@Start,GETDATE())
   --IF @Err <> 0
   --   EXEC dbo.ispLogSQL   @DB, @Schema, @Proc, @Id, @Stmt, @Duration

   SELECT
      @Description = ISNULL(@Description, ''),
      @Short = ISNULL(@Short, ''),
      @Long = ISNULL(@Long, ''),
      @Notes = ISNULL(@Notes, ''),
      @Notes2 = ISNULL(@Notes2, ''),
      @UDF01 = ISNULL(@UDF01, ''),
      @UDF02 = ISNULL(@UDF02, ''),
      @UDF03 = ISNULL(@UDF03, ''),
      @UDF04 = ISNULL(@UDF04, ''),
      @UDF05 = ISNULL(@UDF05, '')

END

GO