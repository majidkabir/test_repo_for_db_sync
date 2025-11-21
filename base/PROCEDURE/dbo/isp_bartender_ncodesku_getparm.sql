SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO



/******************************************************************************/
/* Copyright: IDS                                                             */
/* Purpose: isp_Bartender_NCODESKU_GetParm                                    */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 2022-06-22 1.0  CSCHONG    Devops Scripts Combine & Created (WMS-20019)    */
/******************************************************************************/

CREATE PROC [dbo].[isp_Bartender_NCODESKU_GetParm]
(  @c_parm01            NVARCHAR(250),
   @c_parm02            NVARCHAR(250),
   @c_parm03            NVARCHAR(250),
   @c_parm04            NVARCHAR(250),
   @c_parm05            NVARCHAR(250),
   @c_parm06            NVARCHAR(250),
   @c_parm07            NVARCHAR(250),
   @c_parm08            NVARCHAR(250),
   @c_parm09            NVARCHAR(250),
   @c_parm10            NVARCHAR(250),
   @b_debug             INT = 0
)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE
      @n_intFlag         INT,
      @n_CntRec          INT,
      @c_SQL             NVARCHAR(4000),
      @c_SQLSORT         NVARCHAR(4000),
      @c_SQLJOIN         NVARCHAR(4000),
      @c_sku             NVARCHAR(20),
      @n_Idx             INT,
      @c_storerkey       NVARCHAR(20)

  DECLARE @d_Trace_StartTime   DATETIME,
           @d_Trace_EndTime    DATETIME,
           @c_Trace_ModuleName NVARCHAR(20),
           @d_Trace_Step1      DATETIME,
           @c_Trace_Step1      NVARCHAR(20),
           @c_UserName         NVARCHAR(20)

   SET @d_Trace_StartTime = GETDATE()
   SET @c_Trace_ModuleName = ''

    -- SET RowNo = 0

       IF CHARINDEX('-', @c_parm01) > 1
       BEGIN
              SET @n_Idx = CHARINDEX('-', @c_parm01)  
              SET @c_sku = SUBSTRING(@c_parm01, 1, @n_Idx - 1)
       END
       ELSE
       BEGIN
           SET @c_sku = @c_parm01
       END
     

       SELECT DISTINCT PARM1=S.StorerKey, PARM2=S.sku,PARM3='',PARM4='',PARM5='',PARM6='',PARM7='',PARM8='',PARM9='',PARM10=''
       ,Key1='sku',Key2='',Key3='',Key4='',Key5=''
       FROM SKU S WITH (NOLOCK)
       WHERE s.sku = @c_sku
       AND S.StorerKey = CASE WHEN ISNULL(@c_parm02,'') <> '' THEN @c_parm02 ELSE S.storerkey END
 
   EXIT_SP:

      SET @d_Trace_EndTime = GETDATE()
      SET @c_UserName = SUSER_SNAME()


   END -- procedure



GO