SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/
/* Copyright: IDS                                                             */
/* Purpose: isp_Bartender_PALLETLBL5_GetParm                                  */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 2022-JUN-10 1.1  CSCHONG   Devops SCripts Combien & WMS-19781 - created    */
/******************************************************************************/

CREATE PROC [dbo].[isp_Bartender_PALLETLBL5_GetParm]
(  @parm01            NVARCHAR(250),
   @parm02            NVARCHAR(250),
   @parm03            NVARCHAR(250),
   @parm04            NVARCHAR(250),
   @parm05            NVARCHAR(250),
   @parm06            NVARCHAR(250),
   @parm07            NVARCHAR(250),
   @parm08            NVARCHAR(250),
   @parm09            NVARCHAR(250),
   @parm10            NVARCHAR(250),
   @b_debug           INT = 0
)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE
      @c_SQL             NVARCHAR(4000),
      @c_SQLSORT         NVARCHAR(4000),
      @c_SQLJOIN         NVARCHAR(4000),
      @c_condition1      NVARCHAR(150) ,
      @c_condition2      NVARCHAR(150),
      @c_SQLGroup        NVARCHAR(4000),
      @c_SQLOrdBy        NVARCHAR(150),
      @c_SQLinsert       NVARCHAR(4000) ,
      @c_SQLSelect       NVARCHAR(4000),
      @c_printbyRec      NVARCHAR(1),
      @c_printbyLLI      NVARCHAR(1)


  DECLARE  @d_Trace_StartTime   DATETIME,
           @d_Trace_EndTime    DATETIME,
           @c_Trace_ModuleName NVARCHAR(20),
           @d_Trace_Step1      DATETIME,
           @c_Trace_Step1      NVARCHAR(20),
           @c_UserName         NVARCHAR(20),
           @c_getUCCno         NVARCHAR(20),
           @c_getUdef09        NVARCHAR(30),
           @c_ExecStatements   NVARCHAR(4000),
           @c_ExecArguments    NVARCHAR(4000),
           @n_Pqty             INT,
           @n_rowno            INT


DECLARE @c_ttlpage       INT      
       ,@n_PrnQty        INT     
       ,@n_maxpage       INT
       ,@c_Getid         NVARCHAR(18)
       ,@c_sku           NVARCHAR(20)
       ,@c_storerkey     NVARCHAR(20)
       ,@n_currentpage   INT
       ,@n_qty           INT
       ,@n_casecnt       INT
       ,@c_presku        NVARCHAR(20)
       ,@n_prncopy       INT
       ,@c_lastcopyqty   INT

   SET @d_Trace_StartTime = GETDATE()
   SET @c_Trace_ModuleName = ''

    -- SET RowNo = 0
    SET @c_SQL = ''
    SET @c_SQLJOIN = ''
    SET @c_condition1 = ''
    SET @c_condition2= ''
    SET @c_SQLOrdBy = ''
    SET @c_SQLGroup = ''
    SET @c_ExecStatements = ''
    SET @c_ExecArguments = ''
    SET @c_SQLinsert = ''
    SET @c_SQLSelect = ''
    SET @c_printbyRec = 'N'
    SET @c_printbyLLI = 'N'
   
    SET @n_maxpage = 150
    SET @n_currentpage = 1
    SET @c_presku = ''


    CREATE TABLE #TMP_Result (
      PARM1     NVARCHAR(80),
      PARM2     NVARCHAR(80),
      PARM3     NVARCHAR(80),
      PARM4     NVARCHAR(80),
      PARM5     NVARCHAR(80),
      PARM6     NVARCHAR(80),
      PARM7     NVARCHAR(80),
      PARM8     NVARCHAR(80),
      PARM9     NVARCHAR(80),
      PARM10    NVARCHAR(80),
      Key01     NVARCHAR(80),
      Key02     NVARCHAR(80),
      Key03     NVARCHAR(80),
      Key04     NVARCHAR(80),
      Key05     NVARCHAR(80) )

  CREATE TABLE #TMPLOTIDTBL (
                             ID            NVARCHAR(20),
                             Storerkey     NVARCHAR(20),
                             SKU           NVARCHAR(20),
                             QTY           INT,
                             CASECNT       INT                          
  
    )

SET @n_maxpage = 150
SET @n_currentpage = 1
SET @c_presku = ''
 

INSERT INTO #TMPLOTIDTBL
(
    ID,
    Storerkey,
    SKU,
    QTY,
    CASECNT
)
SELECT lli.id,lli.StorerKey,lli.sku,SUM(lli.Qty) AS qty, CAST(p.CaseCnt AS INT)--,SUM(lli.Qty)/NULLIF(CAST(p.CaseCnt AS INT),0),SUM(lli.Qty)%NULLIF(CAST(p.CaseCnt AS INT),0) AS ttl
FROM dbo.LOTxLOCxID lli (NOLOCK)
JOIN SKU S WITH (NOLOCK) ON s.StorerKey=lli.StorerKey AND s.sku = lli.Sku
JOIN Pack P WITH (NOLOCK) ON P.PackKey = s.PACKKey
WHERE lli.id = @parm01
GROUP BY lli.StorerKey,lli.sku, CAST(p.CaseCnt AS INT),lli.id
ORDER BY lli.Id DESC


--SELECT * FROM #TMPLOTIDTBL


   DECLARE CUR_RowNoLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
   SELECT DISTINCT id,Storerkey,sku,QTY,CASECNT     
   FROM #TMPLOTIDTBL 
   ORDER BY id,Storerkey,sku                     
            
   OPEN CUR_RowNoLoop                    
               
   FETCH NEXT FROM CUR_RowNoLoop INTO @c_Getid,@c_storerkey,@c_sku,@n_qty,@n_casecnt   
                 
   WHILE @@FETCH_STATUS <> -1               
   BEGIN   

        IF @c_presku = ''
        BEGIN
              SET @c_presku = @c_sku
        END
  
   IF @c_presku<>@c_sku
   BEGIN
      SET @n_PrnQty = 1
   END

        IF @n_qty < @n_casecnt OR @n_qty = @n_casecnt
        BEGIN
           SET @n_PrnQty = @n_qty
           SET @n_prncopy = 1
        END
        ELSE
        BEGIN 
             IF @n_qty%@n_casecnt <> 0
             BEGIN
                SET @n_prncopy = (@n_qty/@n_casecnt) + 1 
             END
             ELSE
             BEGIN
                SET @n_prncopy = (@n_qty/@n_casecnt)
             END
        END

  --  print 'prncopy :' + CAST(@n_prncopy AS NVARCHAR(10)) 
   --GOTO EXIT_SP

        IF @n_prncopy = 1
        BEGIN
              INSERT INTO #TMP_Result
              (
                  PARM1,
                  PARM2,
                  PARM3,
                  PARM4,
                  PARM5,
                  PARM6,
                  PARM7,
                  PARM8,
                  PARM9,
                  PARM10,
                  Key01,
                  Key02,
                  Key03,
                  Key04,
                  Key05
              )
              VALUES
              (   @c_storerkey, -- PARM1 - nvarchar(80)
                  @c_sku, -- PARM2 - nvarchar(80)
                  @n_PrnQty, -- PARM3 - nvarchar(80)
                  @c_Getid, -- PARM4 - nvarchar(80)
                  N'', -- PARM5 - nvarchar(80)
                  N'', -- PARM6 - nvarchar(80)
                  N'', -- PARM7 - nvarchar(80)
                  N'', -- PARM8 - nvarchar(80)
                  N'', -- PARM9 - nvarchar(80)
                  N'', -- PARM10 - nvarchar(80)
                  N'ID', -- Key01 - nvarchar(80)
                  N'', -- Key02 - nvarchar(80)
                  N'', -- Key03 - nvarchar(80)
                  N'', -- Key04 - nvarchar(80)
                  N''  -- Key05 - nvarchar(80)
                  )
        END
        ELSE
        BEGIN

           

           WHILE @n_prncopy>=1
           BEGIN
            
             -- SELECT 'Get',@n_PrnQty '@n_PrnQty',@n_prncopy '@n_prncopy', @n_casecnt '@n_casecnt', @n_qty%@n_casecnt '@n_qty%@n_casecnt'
             --print 'Get prncopy :' + CAST(@n_prncopy AS NVARCHAR(10)) 

               IF @n_prncopy = 1
               BEGIN
                    IF  @n_qty%@n_casecnt <> 0
                    BEGIN
                        SET @n_PrnQty = @n_qty%@n_casecnt
                    END
                    ELSE
                    BEGIN
                        SET @n_PrnQty = @n_casecnt
                    END 
               END 
               ELSE
               BEGIN
                       SET @n_PrnQty = @n_casecnt
               END    

         
              INSERT INTO #TMP_Result
              (
                  PARM1,
                  PARM2,
                  PARM3,
                  PARM4,
                  PARM5,
                  PARM6,
                  PARM7,
                  PARM8,
                  PARM9,
                  PARM10,
                  Key01,
                  Key02,
                  Key03,
                  Key04,
                  Key05
              )
              VALUES
              (   @c_storerkey, -- PARM1 - nvarchar(80)
                  @c_sku, -- PARM2 - nvarchar(80)
                  @n_PrnQty, -- PARM3 - nvarchar(80)
                  @c_Getid, -- PARM4 - nvarchar(80)
                  N'', -- PARM5 - nvarchar(80)
                  N'', -- PARM6 - nvarchar(80)
                  N'', -- PARM7 - nvarchar(80)
                  N'', -- PARM8 - nvarchar(80)
                  N'', -- PARM9 - nvarchar(80)
                  N'', -- PARM10 - nvarchar(80)
                  N'ID', -- Key01 - nvarchar(80)
                  N'', -- Key02 - nvarchar(80)
                  N'', -- Key03 - nvarchar(80)
                  N'', -- Key04 - nvarchar(80)
                  N''  -- Key05 - nvarchar(80)
                  )

                SET @n_prncopy = @n_prncopy - 1
                
                SET @n_currentpage = @n_currentpage + 1

               IF @n_currentpage > @n_maxpage  
               BEGIN  
                  BREAK;  
               END 
           END 

        END
          
        SET @c_presku = @c_sku             

   FETCH NEXT FROM CUR_RowNoLoop INTO @c_Getid,@c_storerkey,@c_sku,@n_qty,@n_casecnt           
   END

    SELECT * FROM #TMP_Result
 --select * from #TEMP_PICKBYQTY


   EXIT_SP:

      SET @d_Trace_EndTime = GETDATE()
      SET @c_UserName = SUSER_SNAME()

         IF OBJECT_ID('tempdb..#TMPLOTIDTBL') IS NOT NULL
         BEGIN
            DROP TABLE #TMPLOTIDTBL
         END

         IF OBJECT_ID('tempdb..#TMP_Result') IS NOT NULL
         BEGIN
            DROP TABLE #TMP_Result
         END

   END -- procedure


GO