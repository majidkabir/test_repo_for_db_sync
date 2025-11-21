SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  isp_Packing_List_89_rdt                            */
/* Creation Date: 10-NOV-2020                                           */
/* Copyright: IDS                                                       */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose: WMS-15607 [CN] ZCJ_B2B_Carton Label                         */
/*                                                                      */
/*                                                                      */
/* Input Parameters: (PickSlipNo, CartonNoStart, CartonNoEnd)           */
/*                   OR ExternOrderKey                                  */
/*                                                                      */
/* Output Parameters:                                                   */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Called By:  r_dw_Packing_List_89_rdt                                 */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/************************************************************************/

CREATE PROC [dbo].[isp_Packing_List_89_rdt] (
           @c_PickSlipNo     NVARCHAR(20) 
)
AS
BEGIN

   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  @n_Continue      INT = 1
          , @b_debug         INT = 0
          , @c_GetPickslipno NVARCHAR(20) = ''
          , @nCartonNo       INT   
          , @n_MaxLineno     INT = 5                 
          , @n_CurrentRec    INT            
          , @n_MaxRec        INT            
          , @n_cartonno      INT
          , @n_TTLCTN        INT
          , @c_PrnByPickslip NVARCHAR(1)
          , @c_PrnByLabelno  NVARCHAR(1)            

  

   DECLARE @c_ExecStatements       NVARCHAR(4000)  
         , @c_ExecArguments        NVARCHAR(4000)  
         , @c_SQLJoin              NVARCHAR(4000)
         , @c_where                NVARCHAR(4000)  
         , @c_SQL                  NVARCHAR(MAX) 
         , @c_grpby                NVARCHAR(4000)  
         , @c_Storerkey            NVARCHAR(20)

   SET @c_PrnByPickslip = 'N'
   SET @c_PrnByLabelno  = 'N'
   SET @n_TTLCTN = 1

   --Check Pickslipno or labelno
   IF EXISTS (SELECT 1 FROM PACKHEADER (NOLOCK) WHERE pickslipno = @c_pickslipno)
   BEGIN
       SET @c_PrnByPickslip = 'Y'
   
       SELECT @n_TTLCTN = MAX(cartonno)
       FROM PACKDETAIL (NOLOCK)
       WHERE Pickslipno = @c_pickslipno

       SET @c_where = N' WHERE PH.Pickslipno = @c_pickslipno'  

   END
   ELSE IF EXISTS (SELECT 1 FROM PACKDETAIL (NOLOCK) WHERE labelno = @c_pickslipno)  
   BEGIN
       SET @c_PrnByLabelno = 'Y'
       SET @c_GetPickslipno = ''

       SELECT TOP 1 @c_GetPickslipno = Pickslipno
       FROM PACKDETAIL (NOLOCK)
       WHERE labelno = @c_pickslipno


       SELECT @n_TTLCTN = MAX(cartonno)
       FROM PACKDETAIL (NOLOCK)
       WHERE Pickslipno = @c_GetPickslipno

        SET @c_where = N' WHERE PD.labelno = @c_pickslipno'  
   END

   CREATE TABLE #RESULT_PKL98(
      -- rowid           int NOT NULL identity(1,1) PRIMARY KEY,     
       PickSlipNo      NVARCHAR(10) NULL,
       LoadKey         NVARCHAR(10) NULL,
       SKU             NVARCHAR(50) NULL,
       Qty             INT NULL,
       CState          NVARCHAR(45) NULL,
       ExtOrdKey       NVARCHAR(50) NULL,
       LABELNO         NVARCHAR(20) NULL,
       CCompany        NVARCHAR(45) NULL,
       CAddress1       NVARCHAR(45) NULL,
       CartonNo        INT NULL,
       LOTT04          NVARCHAR(10) NULL,  
       LOC             NVARCHAR(10) NULL,  
       CCountry        NVARCHAR(45) NULL,  
       CCity           NVARCHAR(45) NULL,  
       CContact1       NVARCHAR(45) NULL,
       CPhone1         NVARCHAR(45) NULL,
       TTLCTN          INT  NULL
  
   )

      SET @c_SQL = 'INSERT INTO #RESULT_PKL98
                    SELECT PD.Pickslipno
                          ,ORD.LOADKEY
                          ,PD.SKU
                          ,SUM(PID.QTY)
                          ,ORD.C_State
                          ,ORD.ExternOrderkey
                          ,UPPER(PD.LABELNO)
                          ,ORD.c_Company      
                          ,ISNULL(ORD.c_Address1,'''')
                          ,PD.CartonNo
                          ,REPLACE(CONVERT(NVARCHAR(10),LOTT.Lottable04,102),''.'','''')  
                          ,ISNULL(PID.LOC,'''')    
                          ,ISNULL(ORD.C_Country,'''')      
                          ,ISNULL(ORD.c_city,'''')    
                          ,ISNULL(ORD.c_contact1,'''')    
                          ,ISNULL(ORD.c_phone1,'''')
                          ,@n_TTLCTN as TTLCTN
                    FROM PACKDETAIL PD WITH (NOLOCK)
                    JOIN PACKHEADER PH WITH (NOLOCK) ON PH.PICKSLIPNO = PD.PICKSLIPNO
                    JOIN ORDERS ORD WITH (NOLOCK) ON ORD.ORDERKEY = PH.ORDERKEY
                    JOIN SKU S WITH (NOLOCK) ON S.SKU = PD.SKU AND S.STORERKEY = ORD.STORERKEY
                    JOIN PICKDETAIL PID  WITH (NOLOCK) ON PID.caseid = PD.labelno
                    JOIN LOTATTRIBUTE LOTT WITH (NOLOCK) ON (LOTT.SKU=PID.SKU AND LOTT.Storerkey=PID.Storerkey AND LOTT.lot=PID.Lot) '
   SET @c_grpby = '   
                    GROUP BY PD.Pickslipno
                            ,ORD.LOADKEY
                            ,PD.SKU
                          --  ,PID.QTY
                            ,ORD.C_State
                            ,ORD.ExternOrderkey
                            ,UPPER(PD.LABELNO)
                            ,ORD.c_Company
                            ,ISNULL(ORD.c_Address1,'''')
                            ,PD.CartonNo
                            ,REPLACE(CONVERT(NVARCHAR(10),LOTT.Lottable04,102),''.'','''')  
                            ,ISNULL(PID.LOC,'''')    
                            ,ISNULL(ORD.C_Country,'''') 
                            ,ISNULL(ORD.c_city,'''')    
                            ,ISNULL(ORD.c_contact1,'''')      
                            ,ISNULL(ORD.c_phone1,'''')    
                    ORDER BY PD.Pickslipno, PD.CartonNo,PD.SKU,REPLACE(CONVERT(NVARCHAR(10),LOTT.Lottable04,102),''.'','''')    '

      SET @c_ExecStatements = @c_SQL + CHAR(13) + @c_where + CHAR(13) + @c_grpby

      
      SET @c_ExecArguments = N'   @c_pickslipno     NVARCHAR(20)'
                          + ' ,@n_TTLCTN         INT '  

       EXEC sp_ExecuteSql   @c_ExecStatements     
                          , @c_ExecArguments    
                          , @c_pickslipno  
                          , @n_TTLCTN
 
   
    --     print @c_ExecStatements  
                
   SELECT  *
   FROM #RESULT_PKL98                 
   ORDER BY Pickslipno, CartonNo, SKU           

   
   IF OBJECT_ID('tempdb..#RESULT_PKL98 ','u') IS NOT NULL 
   DROP TABLE #RESULT_PKL98

 
END


GO