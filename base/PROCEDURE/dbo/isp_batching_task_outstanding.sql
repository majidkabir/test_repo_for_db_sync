SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store Procedure: isp_batching_task_outstanding                       */
/* Creation Date: 08-Aug-2016                                           */
/* Copyright: LF Logistics                                              */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose: SOS#374971 - New ECOM Report                                */
/*        :                                                             */
/* Called By: r_dw_batching_task_outstanding                            */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_batching_task_outstanding]
            @c_TaskBatchNo NVARCHAR(10)                      
         ,  @c_Orderkey    NVARCHAR(10) = ''

AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT 
         , @c_SQL             NVARCHAR(4000)        
         , @c_SQLGroup        NVARCHAR(4000)        
         , @c_SQLJOIN         NVARCHAR(4000)      
			, @c_condition       NVARCHAR(150)
			
   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1

   IF RTRIM(@c_TaskBatchNo) = '' OR @c_TaskBatchNo IS NULL
   BEGIN
      GOTO QUIT_SP 
   END

   CREATE TABLE #TMP_PACKOUTSTDSUMMARY
      (  TaskBatchNo    NVARCHAR(10)   NULL
      ,  TaskDetailKey  NVARCHAR(10)   NULL
      ,  TaskName       NVARCHAR(150)  NULL
      ,  loadkey        NVARCHAR(15)   NULL
      ,  PTOrderkey     NVARCHAR(10)   NULL
      ,  Orderkey       NVARCHAR(10)   NULL
      ,  OrdStatus      NVARCHAR(10)   NULL
      ,  ORDSOStatus    NVARCHAR(10)   NULL
      ,  Loc            NVARCHAR(10)   NULL
      ,  ORDMode        NVARCHAR(10)   NULL
      ,  modedesc    NVARCHAR(50)   NULL
      ,  SKu            NVARCHAR(15)   NULL
      ,  SDescr         NVARCHAR(200)  NULL
      ,  CaseCnt        FLOAT       
      ,  PQty           INT            NULL
 
      )
      
      

   SET @c_sqljoin = 'SELECT DISTINCT PT.TaskBatchNo,PD.Pickslipno,PD.Notes,lp.LoadKey,'''', '+              
						'	CASE WHEN RIGHT(PT.OrderMode,1) in (''5'',''9'') THEN '''' ELSE pd.OrderKey END AS ORDKEY '+
						'  ,ord.[Status],ord.SOStatus,Pd.Loc,RIGHT(PT.OrderMode,1) AS ORDMode, ' +                                  
						'  CASE WHEN RIGHT(PT.OrderMode,1) = ''1'' THEN ''Multi-S''  '+                             
						'  WHEN RIGHT(PT.OrderMode,1) IN (''0'',''4'') THEN ''Multi-M''  '+                          
						'  WHEN RIGHT(PT.OrderMode,1) = ''5'' THEN ''BIG'' '+                                      
						'  WHEN RIGHT(PT.OrderMode,1) = ''9'' THEN ''Single'' END AS ModeDescr,  '+                
						'  PD.Sku,S.DESCR,ISNULL(p.CaseCnt,1),SUM(PD.qty)  '+                                          
						'  FROM PACKTASK PT WITH (NOLOCK)     '+                                               
						'  JOIN Orders ORD WITH (NOLOCK) ON ORD.Orderkey = PT.Orderkey  '+                     
						'  JOIN LoadPlan AS lp WITH (NOLOCK) ON lp.LoadKey=ord.LoadKey  '+                    
						'  JOIN PICKDETAIL AS PD WITH (NOLOCK) ON pd.PickSlipNo=PT.TaskBatchNo and pd.OrderKey=ord.OrderKey '+
						'  JOIN SKU S WITH (NOLOCK) ON s.StorerKey=PD.Storerkey AND S.sku = PD.sku      '+     
						'  JOIN PACK P WITH (NOLOCK) ON p.PackKey=s.PACKKey      '+                            
						'  WHERE PT.TaskBatchNo= ''' + @c_TaskBatchNo + ''''+                                                
						'  AND PD.Orderkey = CASE WHEN ISNULL(''' + @c_orderkey + ''','''') <> '''' THEN ''' + @c_orderkey + ''' ELSE PD.Orderkey END '                                         
						
						
	SET @c_SQLGroup = ' GROUP BY PT.TaskBatchNo,PD.Pickslipno,PD.Notes,lp.LoadKey, '+                    
						   ' CASE WHEN RIGHT(PT.OrderMode,1) in (''5'',''9'') THEN '''' ELSE pd.OrderKey END '+         
						   ' ,ord.[Status],ord.SOStatus, '+                                                       
					    	' Pd.Loc,RIGHT(PT.OrderMode,1),PD.Sku,S.DESCR,p.CaseCnt '+                                      
					      ' ORDER BY CASE WHEN RIGHT(PT.OrderMode,1) in (''5'',''9'') THEN '''' ELSE pd.OrderKey END '					

   SET @c_sql = 'INSERT INTO #TMP_PACKOUTSTDSUMMARY (' +
                ' TaskBatchNo,TaskDetailKey,TaskName, ' +     
                ' loadkey,PTOrderkey,Orderkey,OrdStatus,ORDSOStatus, '+   
                ' Loc,ORDMode,modedesc,SKu,SDescr, ' +      
                ' CaseCnt,PQty) '
                
   SET @c_condition = ''
                
   IF ISNULL(@c_Orderkey,'') = '' 
   BEGIN
   	SET @c_condition = ' AND Ord.Status not in(''5'',''9'')'
   END             
   
    SET @c_SQL = @c_SQL + @c_SQLJOIN  + @c_condition + @c_SQLGroup

        
     EXEC sp_executesql @c_SQL       
        
   SELECT *
   FROM #TMP_PACKOUTSTDSUMMARY
   WHERE TaskBatchNo = @c_TaskBatchNo
   AND   Orderkey = CASE WHEN ISNULL(@c_orderkey,'') <> '' THEN @c_Orderkey ELSE Orderkey END

QUIT_SP:
  
END -- procedure


GO