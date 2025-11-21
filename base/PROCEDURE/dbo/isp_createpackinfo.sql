SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/      
/* Stored Procedure: isp_CreatePackInfo                                 */      
/* Creation Date: 17-Jul-2019                                           */      
/* Copyright: LF                                                        */      
/* Written by: WLChooi                                                  */      
/*                                                                      */      
/* Purpose:  Move CreatePackInfo process to backend                     */    
/*                                                                      */      
/* Called By: Packing Module                                            */        
/*            Scan And Pack Module                                      */    
/*                                                                      */      
/* PVCS Version: 1.0                                                    */      
/*                                                                      */      
/* Version: 5.4                                                         */      
/*                                                                      */      
/* Data Modifications:                                                  */      
/*                                                                      */      
/* Updates:                                                             */      
/* Date        Author   Ver   Purposes                                  */    
/* 05-Mar-2020  WLChooi  1.1  WMS-11775-Storerconfig: DefaultCartonType */    
/*                            Auto insert PackInfo.CartonType (WL01)    */    
/* 2020-04-28   Wan01    1.2  WMS-12722 - SG - PMI - Packing [CR]       */   
/* 14-May-2020  WLChooi  1.3  Bug Fix for WMS-9661 (WL02)               */    
/* 15-May-2020  WLChooi  1.4  Insert PACKInfo table with CartonType =   */  
/*                            NULL (WL03)                               */ 
/* 14-Dec-2020  WLChooi  1.5  WMS-15830 - Populate Length, Width, Height*/
/*                            From Cartonization (WL04)                 */ 
/************************************************************************/      
    
CREATE PROCEDURE [dbo].[isp_CreatePackInfo]    
      @c_Pickslipno     NVARCHAR(50)    
   ,  @c_CallFrom       NVARCHAR(20)      
   ,  @c_Storerkey      NVARCHAR(10)      
   ,  @b_Success        INT           OUTPUT     
   ,  @n_Err            INT           OUTPUT     
   ,  @c_ErrMsg         NVARCHAR(250) OUTPUT    
   ,  @c_ScanUPCUOM     NVARCHAR(250) = ''   --WL01    
AS    
BEGIN    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
       
   DECLARE  @n_Continue            INT,    
            @n_StartTCnt           INT,    
            @n_GetCartonNo         INT,    
            @n_CartonNo            INT,    
            @c_Facility            NVARCHAR(20),    
            @c_CartonGID           NVARCHAR(50),    
            @c_DefaultPackInfo     NVARCHAR(10) = '',    
            @c_CapturePackInfo     NVARCHAR(10) = '',    
            @c_PackCartonGID       NVARCHAR(10) = '',    
            @c_DefaultCartonType   NVARCHAR(10) = '',   --WL01         
            @c_Option1             NVARCHAR(50) = '',   --WL01         
            @c_UPCUOM              NVARCHAR(50) = '',   --WL01    
            @c_CartonType          NVARCHAR(50) = ''    --WL01    
    
           ,  @c_PackPreCaseID        NVARCHAR(30)= ''     --(Wan01)  
           ,  @c_Orderkey             NVARCHAR(10)= ''     --(Wan01)  
           
           ,  @c_Option2             NVARCHAR(50)   = ''   --WL04
           ,  @c_Option3             NVARCHAR(50)   = ''   --WL04
           ,  @c_Option4             NVARCHAR(50)   = ''   --WL04
           ,  @c_Option5             NVARCHAR(4000) = ''   --WL04
           ,  @c_DefaultLWH          NVARCHAR(10)   = ''   --WL04
           
   DECLARE @t_DropID  TABLE                              --(Wan01)  
         (  DropID NVARCHAR(20)  DEFAULT(0) PRIMARY KEY )--(Wan01)  
     
   SELECT @n_continue = 1, @n_Err = 0, @b_Success = 1, @c_ErrMsg = '', @n_StartTCnt = @@TRANCOUNT    
       
   --INSERT INTO TRACEINFO (TraceName, Step1, Step2, Step3)    
   --SELECT 'isp_CreatePackInfo', 'Pickslipno', 'CartonNo', 'CartonGID'    
    
   SELECT TOP 1 @c_Facility = Facility    
   FROM PACKHEADER (NOLOCK)     
   JOIN ORDERS (NOLOCK) ON PACKHEADER.StorerKey = ORDERS.StorerKey AND PACKHEADER.OrderKey = ORDERS.OrderKey    
   WHERE Pickslipno = @c_Pickslipno    
    
   IF(ISNULL(@c_Facility,'') = '')    
   BEGIN    
      SELECT TOP 1 @c_Facility = Facility    
      FROM PACKHEADER (NOLOCK)     
      JOIN LOADPLANDETAIL (NOLOCK) ON LOADPLANDETAIL.LOADKEY = PACKHEADER.LOADKEY    
      JOIN ORDERS (NOLOCK) ON ORDERS.ORDERKEY = LOADPLANDETAIL.ORDERKEY    
      WHERE Pickslipno = @c_Pickslipno    
   END    
    
   IF @n_Continue IN (1,2)    
   BEGIN    
      EXEC nspGetRight       
         @c_Facility          -- facility      
      ,  @c_Storerkey         -- Storerkey      
      ,  NULL                 -- Sku      
      ,  'Capture_PackInfo'   -- Configkey      
      ,  @b_Success           OUTPUT       
      ,  @c_CapturePackInfo   OUTPUT       
      ,  @n_Err               OUTPUT       
      ,  @c_ErrMsg            OUTPUT     
          
      IF @b_success <> 1      
      BEGIN      
         SET @n_continue = 3      
         SET @n_err = 60060       
         SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Executing nspGetRight. (isp_CreatePackInfo)'       
                     + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '       
         GOTO QUIT      
      END     
    
      EXEC nspGetRight       
         @c_Facility          -- facility      
      ,  @c_Storerkey         -- Storerkey      
      ,  NULL                 -- Sku      
      ,  'Default_PackInfo'   -- Configkey      
      ,  @b_Success           OUTPUT       
      ,  @c_DefaultPackInfo   OUTPUT       
      ,  @n_Err               OUTPUT       
      ,  @c_ErrMsg            OUTPUT  
      ,  @c_Option1           OUTPUT   --WL04
      ,  @c_Option2           OUTPUT   --WL04
      ,  @c_Option3           OUTPUT   --WL04
      ,  @c_Option4           OUTPUT   --WL04
      ,  @c_Option5           OUTPUT   --WL04
      
      IF @b_success <> 1      
      BEGIN      
         SET @n_continue = 3      
         SET @n_err = 60065       
         SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Executing nspGetRight. (isp_CreatePackInfo)'       
                     + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '       
         GOTO QUIT      
      END    
      
      SELECT @c_DefaultLWH = dbo.fnc_GetParamValueFromString('@c_DefaultLWH', @c_Option5, @c_DefaultLWH)   --WL04  
          
      EXEC nspGetRight       
         @c_Facility          -- facility      
      ,  @c_Storerkey         -- Storerkey      
      ,  NULL                 -- Sku      
      ,  'PackCartonGID'      -- Configkey      
      ,  @b_Success           OUTPUT       
      ,  @c_PackCartonGID     OUTPUT       
      ,  @n_Err               OUTPUT       
      ,  @c_ErrMsg            OUTPUT     
          
      IF @b_success <> 1      
      BEGIN      
         SET @n_continue = 3      
         SET @n_err = 60070       
         SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Executing nspGetRight. (isp_CreatePackInfo)'       
                     + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '       
         GOTO QUIT      
      END     
    
      --WL01 START    
      EXEC nspGetRight       
         @c_Facility              -- facility      
      ,  @c_Storerkey             -- Storerkey      
      ,  NULL                     -- Sku      
      ,  'DefaultCartonType'      -- Configkey      
      ,  @b_Success               OUTPUT       
      ,  @c_DefaultCartonType     OUTPUT       
      ,  @n_Err                   OUTPUT       
      ,  @c_ErrMsg                OUTPUT     
      ,  @c_Option1               OUTPUT    
          
      IF @b_success <> 1      
      BEGIN      
         SET @n_continue = 3      
         SET @n_err = 60090       
         SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Executing nspGetRight. (isp_CreatePackInfo)'       
                     + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '       
         GOTO QUIT      
      END     
    
      IF ISNULL(@c_DefaultCartonType,'') = '1' AND ISNULL(@c_Option1,'') <> ''    
      BEGIN    
         SELECT @c_UPCUOM = SUBSTRING(LTRIM(RTRIM(@c_Option1)),1,CHARINDEX('=',LTRIM(RTRIM(@c_Option1))) - 1)    
         SELECT @c_CartonType = SUBSTRING(LTRIM(RTRIM(@c_Option1)),CHARINDEX('=',LTRIM(RTRIM(@c_Option1))) + 1, LEN(LTRIM(RTRIM(@c_Option1))))    
      END    
      --WL01 END    
     
      --(Wan01) - START  
      EXEC nspGetRight     
         @c_Facility              -- facility    
      ,  @c_Storerkey             -- Storerkey    
      ,  NULL                     -- Sku    
      ,  'PackPreCaseID'          -- Configkey    
      ,  @b_Success              OUTPUT     
      ,  @c_PackPreCaseID        OUTPUT     
      ,  @n_Err                  OUTPUT     
      ,  @c_ErrMsg               OUTPUT   
      ,  @c_Option1              OUTPUT  
        
      IF @b_success <> 1    
      BEGIN    
         SET @n_continue = 3    
         SET @n_err = 60100     
         SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Executing nspGetRight. (isp_CreatePackInfo)'     
                     + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '     
         GOTO QUIT    
      END   
      --(Wan01) - END  
   END  
  
   DECLARE Cur_Packdetail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT DISTINCT PD.Pickslipno, PD.CartonNo  
   FROM Packdetail PD (NOLOCK)  
   WHERE PD.Pickslipno = @c_Pickslipno  
   ORDER BY PD.CartonNo ASC  
  
    
   IF @n_Continue IN (1,2)    
   BEGIN    
      IF @c_PackCartonGID = '1'    
      BEGIN    
         OPEN Cur_PackDetail    
    
         FETCH NEXT FROM Cur_PackDetail INTO @c_Pickslipno, @n_GetCartonNo    
    
         WHILE @@FETCH_STATUS <> -1    
         BEGIN    
            DECLARE @dt_TimeIn DATETIME, @dt_TimeOut DATETIME    
            SET @dt_TimeIn = GETDATE()    
    
            SELECT @c_CartonGID = CASE WHEN ISNULL(CL.SHORT,'N') = 'Y' AND CAST(CL.LONG AS INT) <> 0 THEN    
                                  CL.UDF01 + RIGHT(REPLICATE('0',CL.LONG) + SUBSTRING(PACKDETAIL.LABELNO,CAST(CL.UDF02 AS INT)    
                                 ,CAST(CL.UDF03 AS INT)-CAST(CL.UDF02 AS INT)+1)    
                                 ,CAST(CL.LONG AS INT)-LEN(CL.UDF01))    
                                  WHEN ISNULL(CL.SHORT,'N') = 'Y' AND CAST(CL.LONG AS INT) = 0 THEN CL.UDF01 + PACKDETAIL.LABELNO ELSE PACKDETAIL.LABELNO END    
            FROM PackDetail with (NOLOCK)    
            OUTER APPLY (SELECT TOP 1 CL.SHORT, CL.LONG, CL.UDF01, CL.UDF02, CL.UDF03, CL.CODE2 FROM    
                         CODELKUP CL WITH (NOLOCK) WHERE (CL.LISTNAME = 'BARCODELEN' AND CL.STORERKEY = PackDetail.STORERKEY AND CL.CODE = 'SUPERHUB' AND    
                        (CL.CODE2 = @c_Facility OR CL.CODE2 = '') ) ORDER BY CASE WHEN CL.CODE2 = '' THEN 2 ELSE 1 END ) AS CL     
            WHERE PACKDETAIL.PickSlipNo = @c_Pickslipno     
            AND   PACKDETAIL.CartonNo = @n_GetCartonNo    
    
            IF NOT EXISTS (SELECT 1 FROM PACKINFO (NOLOCK) WHERE PICKSLIPNO = @c_Pickslipno AND CartonNo = @n_GetCartonNo)    
            BEGIN    
               INSERT INTO PACKINFO (PickSlipNo, CartonNo, CartonType, [Cube], Qty, Weight, CartonGID)    
               SELECT DISTINCT PACKDETAIL.pickslipno, PACKDETAIL.CartonNo, NULL, 0, SUM(PACKDETAIL.Qty), 0, @c_CartonGID   --WL03   --WL02  
               FROM PACKDETAIL (NOLOCK)    
               WHERE PACKDETAIL.PickSlipNo = @c_Pickslipno    
               AND PACKDETAIL.CartonNo NOT IN    
                   (SELECT CartonNo FROM PACKINFO (NOLOCK) WHERE PickSlipNo = @c_Pickslipno)    
               AND PACKDETAIL.CartonNo = @n_GetCartonNo    
               GROUP BY PACKDETAIL.pickslipno, PACKDETAIL.CartonNo   --WL02  
            END    
            ELSE    
            BEGIN    
               UPDATE PACKINFO    
               SET CartonGID = @c_CartonGID    
               WHERE PICKSLIPNO = @c_Pickslipno AND CartonNo = @n_GetCartonNo    
            END    
    
            --SET @dt_TimeOut = GETDATE()    
    
            --INSERT INTO TRACEINFO (TraceName, TimeIn, [TimeOut], Step1, Step2, Step3, Col1, Col2, Col3)    
            --SELECT 'isp_CreatePackInfo', @dt_TimeIn, @dt_TimeOut, 'Pickslipno', 'CartonNo', 'CartonGID', @c_Pickslipno, @n_GetCartonNo, @c_CartonGID    
    
            FETCH NEXT FROM Cur_PackDetail INTO @c_Pickslipno, @n_GetCartonNo    
         END    
         CLOSE Cur_PackDetail    
      END    
   END    
  
   IF @n_Continue IN (1,2)    
   BEGIN    
      IF @c_CapturePackInfo IN ( '1', '2' )  
      BEGIN    
         IF @c_DefaultPackInfo = '1'   
         BEGIN  
         	--WL04 START
            IF @c_DefaultLWH = 'Y'
            BEGIN
               INSERT INTO PACKINFO (PickSlipNo, CartonNo, Qty, CartonType, [Cube], WEIGHT, [Length], [Width], [Height])  
               SELECT DISTINCT PACKDETAIL.pickslipno, PACKDETAIL.CartonNo, SUM(PACKDETAIL.Qty), ISNULL(cz.CartonType,''),  
               CASE WHEN ISNULL(CZ.[Cube],0) = 0 THEN SUM(PACKDETAIL.Qty * Sku.StdCube) ELSE ISNULL(CZ.[Cube],0) END,  
               SUM(PACKDETAIL.Qty * Sku.StdGrossWgt) + ISNULL(CZ.CartonWeight,0) AS WEIGHT,
               ISNULL(CZ.CartonLength,0), ISNULL(CZ.CartonWidth,0), ISNULL(CZ.CartonHeight,0)
               FROM PACKDETAIL (NOLOCK)  
               JOIN STORER (NOLOCK) ON (PACKDETAIL.StorerKey = STORER.StorerKey)  
               JOIN SKU (NOLOCK) ON (PACKDETAIL.Storerkey = SKU.Storerkey AND PACKDETAIL.SKU = SKU.Sku)  
               LEFT JOIN CARTONIZATION CZ (NOLOCK) ON (STORER.CartonGroup = CZ.CartonizationGroup AND CZ.UseSequence = 1)  
               WHERE PACKDETAIL.PickSlipNo = @c_Pickslipno  
               AND PACKDETAIL.CartonNo NOT IN  
                        (SELECT CartonNo FROM PACKINFO (NOLOCK) WHERE PickSlipNo = @c_Pickslipno)  
               GROUP BY PACKDETAIL.PickSlipNo, PACKDETAIL.CartonNo, ISNULL(cz.CartonType,''), ISNULL(CZ.[Cube],0), ISNULL(CZ.CartonWeight,0),
                        ISNULL(CZ.CartonLength,0), ISNULL(CZ.CartonWidth,0), ISNULL(CZ.CartonHeight,0)  
            END
            ELSE
            BEGIN
               INSERT INTO PACKINFO (PickSlipNo, CartonNo, Qty, CartonType, [Cube], Weight)  
               SELECT DISTINCT PACKDETAIL.pickslipno, PACKDETAIL.CartonNo, SUM(PACKDETAIL.Qty), ISNULL(cz.CartonType,''),  
               CASE WHEN ISNULL(CZ.[Cube],0) = 0 THEN SUM(PACKDETAIL.Qty * Sku.StdCube) ELSE ISNULL(CZ.[Cube],0) END,  
               SUM(PACKDETAIL.Qty * Sku.StdGrossWgt) + ISNULL(CZ.CartonWeight,0) AS WEIGHT  
               FROM PACKDETAIL (NOLOCK)  
               JOIN STORER (NOLOCK) ON (PACKDETAIL.StorerKey = STORER.StorerKey)  
               JOIN SKU (NOLOCK) ON (PACKDETAIL.Storerkey = SKU.Storerkey AND PACKDETAIL.SKU = SKU.Sku)  
               LEFT JOIN CARTONIZATION CZ (NOLOCK) ON (STORER.CartonGroup = CZ.CartonizationGroup AND CZ.UseSequence = 1)  
               WHERE PACKDETAIL.PickSlipNo = @c_Pickslipno  
               AND PACKDETAIL.CartonNo NOT IN  
                        (SELECT CartonNo FROM PACKINFO (NOLOCK) WHERE PickSlipNo = @c_Pickslipno)  
               GROUP BY PACKDETAIL.PickSlipNo, PACKDETAIL.CartonNo, ISNULL(cz.CartonType,''), ISNULL(CZ.[Cube],0), ISNULL(CZ.CartonWeight,0)  
            END
            --WL04 END
            
            SELECT @n_Err = @@ERROR  
  
            IF @@ERROR <> 0  
            BEGIN  
               SET @n_continue = 3    
               SET @n_err = 60075     
               SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert To PackInfo table FAILED. (isp_CreatePackInfo)'     
                     + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '     
               GOTO QUIT    
            END     
              
            --WL02 START  
            IF @c_PackCartonGID = '1'    
            BEGIN  
               --INSERT INTO TRACEINFO (TraceName, TimeIn, [TimeOut], Step1, Step2, Step3, Col1, Col2, Col3)    
               --SELECT 'isp_CreatePackInfo', @dt_TimeIn, GETDATE(), 'Pickslipno', 'CartonNo', 'CartonGID', @c_Pickslipno, @n_GetCartonNo, @c_CartonGID    
    
               OPEN Cur_PackDetail    
    
               FETCH NEXT FROM Cur_PackDetail INTO @c_Pickslipno, @n_GetCartonNo    
    
               WHILE @@FETCH_STATUS <> -1    
               BEGIN  
                  IF @c_CallFrom <> 'CONFIRMPACK'  
                  BEGIN  
                     UPDATE PACKINFO    
                     SET CartonType =  ISNULL(cz.CartonType,''),  
                         [Cube]     =  CASE WHEN ISNULL(CZ.[Cube],0) = 0 THEN PD.QtyxStdCube ELSE ISNULL(CZ.[Cube],0) END,     
                         [Weight]   =  PD.QtyxStdGrossWgt + ISNULL(CZ.CartonWeight,0)  
                     FROM PACKDETAIL (NOLOCK)    
                     JOIN STORER (NOLOCK) ON (PACKDETAIL.StorerKey = STORER.StorerKey)    
                     JOIN SKU (NOLOCK) ON (PACKDETAIL.Storerkey = SKU.Storerkey AND PACKDETAIL.SKU = SKU.Sku)    
                     LEFT JOIN CARTONIZATION CZ (NOLOCK) ON (STORER.CartonGroup = CZ.CartonizationGroup AND CZ.UseSequence = 1)    
                     JOIN ( SELECT PACKDETAIL.PickslipNo, PACKDETAIL.CartonNo, SUM(Packdetail.Qty) as Qty, SUM(Packdetail.Qty * Sku.StdCube) as QtyxStdCube,    
                            SUM(Packdetail.Qty * Sku.StdGrossWgt) as QtyxStdGrossWgt    
                            FROM PACKDETAIL (NOLOCK)    
                            JOIN SKU (NOLOCK) ON (PACKDETAIL.Storerkey = SKU.Storerkey AND PACKDETAIL.SKU = SKU.Sku)    
                            WHERE PACKDETAIL.PickSlipNo = @c_Pickslipno AND PACKDETAIL.CartonNo = @n_GetCartonNo    
                            GROUP BY PACKDETAIL.PickslipNo, PACKDETAIL.CartonNo ) PD     
                            ON PD.Pickslipno = PACKDETAIL.PickSlipNo AND PD.CartonNo = PACKDETAIL.CartonNo     
                     WHERE PACKINFO.PickSlipNo = @c_Pickslipno AND PACKINFO.CartonNo = @n_GetCartonNo    
                     AND   PACKDETAIL.PickSlipNo = @c_Pickslipno AND PACKDETAIL.CartonNo = @n_GetCartonNo      --(Wan01)  
                  END  
                  ELSE  
                  BEGIN  
                     UPDATE PACKINFO    
                     SET CartonType =  CASE WHEN ISNULL(PACKINFO.CartonType,'') = '' THEN ISNULL(cz.CartonType,'') ELSE PACKINFO.CartonType END,  
                         [Cube]     =  CASE WHEN ISNULL(PACKINFO.[Cube],0) = 0 THEN   
                                       CASE WHEN ISNULL(CZ.[Cube],0) = 0 THEN PD.QtyxStdCube ELSE ISNULL(CZ.[Cube],0) END  
                                       ELSE PACKINFO.[Cube] END,     
                         [Weight]   =  CASE WHEN ISNULL(PACKINFO.[Weight],0) = 0 THEN PD.QtyxStdGrossWgt + ISNULL(CZ.CartonWeight,0) ELSE PACKINFO.[Weight] END  
                     FROM PACKDETAIL (NOLOCK)    
                     JOIN STORER (NOLOCK) ON (PACKDETAIL.StorerKey = STORER.StorerKey)    
                     JOIN SKU (NOLOCK) ON (PACKDETAIL.Storerkey = SKU.Storerkey AND PACKDETAIL.SKU = SKU.Sku)    
                     LEFT JOIN CARTONIZATION CZ (NOLOCK) ON (STORER.CartonGroup = CZ.CartonizationGroup AND CZ.UseSequence = 1)    
                     JOIN ( SELECT PACKDETAIL.PickslipNo, PACKDETAIL.CartonNo, SUM(Packdetail.Qty) as Qty, SUM(Packdetail.Qty * Sku.StdCube) as QtyxStdCube,    
                            SUM(Packdetail.Qty * Sku.StdGrossWgt) as QtyxStdGrossWgt    
                            FROM PACKDETAIL (NOLOCK)    
                            JOIN SKU (NOLOCK) ON (PACKDETAIL.Storerkey = SKU.Storerkey AND PACKDETAIL.SKU = SKU.Sku)    
                            WHERE PACKDETAIL.PickSlipNo = @c_Pickslipno AND PACKDETAIL.CartonNo = @n_GetCartonNo    
                            GROUP BY PACKDETAIL.PickslipNo, PACKDETAIL.CartonNo ) PD     
                            ON PD.Pickslipno = PACKDETAIL.PickSlipNo AND PD.CartonNo = PACKDETAIL.CartonNo     
                     WHERE PACKINFO.PickSlipNo = @c_Pickslipno AND PACKINFO.CartonNo = @n_GetCartonNo    
                     AND   PACKDETAIL.PickSlipNo = @c_Pickslipno AND PACKDETAIL.CartonNo = @n_GetCartonNo      --(Wan01)  
                  END  
                  FETCH NEXT FROM Cur_PackDetail INTO @c_Pickslipno, @n_GetCartonNo    
               END  
            END  
            --WL02 END  
         END --END DefaultPackInfo  
         ELSE IF @c_PackPreCaseID = '1' ----(Wan01) - START  
         BEGIN  
            SELECT TOP 1  
                     @c_Orderkey = PH.Orderkey  
            FROM  PACKHEADER PH WITH (NOLOCK)  
            WHERE PH.PickSlipNo = @c_Pickslipno  
  
            ;WITH PACK_CTN ( PickSlipNo, CartonNo, DropID, Qty)  
               AS (  SELECT PD.PickSlipNo, PD.CartonNo, PD.DropID, ISNULL(SUM(PD.Qty),0)  
                     FROM PACKDETAIL PD WITH (NOLOCK)  
                     LEFT JOIN PACKINFO PIF WITH (NOLOCK) ON PD.PickSlipNo = PIF.PickSlipNo AND PD.CartonNo = PIF.CartonNo  
                     WHERE PD.PickSlipNo = @c_Pickslipno  
                     AND PIF.CartonNo IS NULL  
                     GROUP BY PD.PickSlipNo, PD.CartonNo, PD.DropID  
                  )  
            ,     PICK_CTN ( DropID, Storerkey, CartonType, UOM )  
               AS  ( SELECT PD.DropID, PD.Storerkey, PD.CartonType, PD.UOM  
                     FROM PICKDETAIL PD WITH (NOLOCK)  
                     WHERE PD.Orderkey = @c_Orderkey  
                     GROUP BY PD.DropID, PD.Storerkey, PD.CartonType, PD.UOM  
                     )  
            
            --WL04 START
            INSERT INTO PACKINFO (PickSlipNo, CartonNo, Qty, CartonType, [Cube], [Weight], [Length], [Width], [Height])  
            SELECT @c_PickSlipNo, PACK.CartonNo, PACK.Qty, ISNULL(CZ.CartonType,'')  
                  ,[Cube]   = ISNULL(CZ.[Cube],0)   
                  ,[Weight] = ISNULL(CZ.MaxWeight,0)   
                  ,[Length] = CASE WHEN @c_DefaultLWH = 'Y' THEN ISNULL(CZ.CartonLength,0) ELSE 0.00 END
                  ,[Width]  = CASE WHEN @c_DefaultLWH = 'Y' THEN ISNULL(CZ.CartonWidth,0)  ELSE 0.00 END
                  ,[Height] = CASE WHEN @c_DefaultLWH = 'Y' THEN ISNULL(CZ.CartonHeight,0) ELSE 0.00 END
            FROM PACK_CTN PACK WITH (NOLOCK)  
            JOIN PICK_CTN PICK WITH (NOLOCK) ON PACK.DropID = PICK.DropID  
            JOIN STORER ST (NOLOCK) ON (PICK.StorerKey = ST.StorerKey)  
            LEFT JOIN CARTONIZATION CZ (NOLOCK) ON (ST.CartonGroup = CZ.CartonizationGroup AND CZ.CartonType = PICK.CartonType)  
            --WL04 END 

            SET @n_Err = @@ERROR  
  
            IF @@ERROR <> 0  
            BEGIN  
               SET @n_continue = 3    
               SET @n_err = 60078   
               SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert To PackInfo table FAILED. (isp_CreatePackInfo)'     
                     + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '     
               GOTO QUIT    
            END    
         END --(Wan01) - END  
         ELSE    
         BEGIN    
            IF @c_CallFrom IN ('CAPTUREPACKINFO', 'SCANNPACK')    
            BEGIN    
               --WL01 START    
               IF @c_UPCUOM = @c_ScanUPCUOM AND @c_DefaultCartonType = '1'    
               BEGIN
                  --WL04 START
                  IF @c_DefaultLWH = 'Y'
                  BEGIN    
                     INSERT INTO PACKINFO (PickSlipNo, CartonNo, Qty, CartonType, [Cube], [Weight], [Length], [Width], [Height])    
                     SELECT DISTINCT PickSlipNo, CartonNo, SUM(Qty), ISNULL(cz.CartonType,''), ISNULL(CZ.[Cube],0), ISNULL(CZ.MaxWeight,0)
                                   , ISNULL(CZ.CartonLength,0), ISNULL(CZ.CartonWidth,0), ISNULL(CZ.CartonHeight,0) 
                     FROM PACKDETAIL (NOLOCK)     
                     JOIN STORER (NOLOCK) ON (PACKDETAIL.StorerKey = STORER.StorerKey)    
                     LEFT JOIN CARTONIZATION CZ (NOLOCK) ON (STORER.CartonGroup = CZ.CartonizationGroup AND CZ.CartonType = @c_CartonType)    
                     WHERE PACKDETAIL.PickSlipNo = @c_Pickslipno      
                     AND PACKDETAIL.CartonNo NOT IN (SELECT CartonNo FROM PACKINFO (NOLOCK) WHERE PickSlipNo = @c_Pickslipno)    
                     GROUP BY PACKDETAIL.PickSlipNo, PACKDETAIL.CartonNo, ISNULL(cz.CartonType,''), ISNULL(CZ.[Cube],0), ISNULL(CZ.MaxWeight,0)  
                            , ISNULL(CZ.CartonLength,0), ISNULL(CZ.CartonWidth,0), ISNULL(CZ.CartonHeight,0) 
                  END
                  ELSE
                  BEGIN
                     INSERT INTO PACKINFO (PickSlipNo, CartonNo, Qty, CartonType, [Cube], [Weight])    
                     SELECT DISTINCT PickSlipNo, CartonNo, SUM(Qty), ISNULL(cz.CartonType,''), ISNULL(CZ.[Cube],0), ISNULL(CZ.MaxWeight,0)    
                     FROM PACKDETAIL (NOLOCK)     
                     JOIN STORER (NOLOCK) ON (PACKDETAIL.StorerKey = STORER.StorerKey)    
                     LEFT JOIN CARTONIZATION CZ (NOLOCK) ON (STORER.CartonGroup = CZ.CartonizationGroup AND CZ.CartonType = @c_CartonType)    
                     WHERE PACKDETAIL.PickSlipNo = @c_Pickslipno      
                     AND PACKDETAIL.CartonNo NOT IN (SELECT CartonNo FROM PACKINFO (NOLOCK) WHERE PickSlipNo = @c_Pickslipno)    
                     GROUP BY PACKDETAIL.PickSlipNo, PACKDETAIL.CartonNo, ISNULL(cz.CartonType,''), ISNULL(CZ.[Cube],0), ISNULL(CZ.MaxWeight,0) 
                  END  
                  --WL04 END
               END    
               ELSE    
               BEGIN    
                  INSERT INTO PACKINFO (PickSlipNo, CartonNo, Qty)    
                  SELECT DISTINCT PickSlipNo, CartonNo, SUM(Qty)    
                  FROM PACKDETAIL (NOLOCK)     
                  WHERE PACKDETAIL.PickSlipNo = @c_Pickslipno      
                  AND PACKDETAIL.CartonNo NOT IN (SELECT CartonNo FROM PACKINFO (NOLOCK) WHERE PickSlipNo = @c_Pickslipno)    
                  GROUP BY PACKDETAIL.PickSlipNo, PACKDETAIL.CartonNo    
               END    
               --WL01 END    
    
               SELECT @n_Err = @@ERROR    
    
               IF @@ERROR <> 0    
               BEGIN    
                  SET @n_continue = 3      
                  SET @n_err = 60080      
                  SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert To PackInfo table FAILED. (isp_CreatePackInfo)'       
                        + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '       
                  GOTO QUIT      
               END    
    
    
            END --Call From    
         END --END Else DefaultPackInfo    
      END --END CapturePackInfo    
   END    
    
   --IF @n_Continue IN (1,2)    
   --BEGIN    
   --   IF @c_PackCartonGID = '1' AND @c_CapturePackInfo = '1'  --WL02    
   --   BEGIN    
    
   --      OPEN Cur_PackDetail    
    
   --      FETCH NEXT FROM Cur_PackDetail INTO @c_Pickslipno, @n_GetCartonNo    
    
   --      WHILE @@FETCH_STATUS <> -1    
   --      BEGIN    
   --         IF EXISTS (SELECT 1 FROM PACKINFO (NOLOCK) WHERE Pickslipno = @c_Pickslipno AND CartonNo = @n_GetCartonNo)    
   --         BEGIN    
   --            DECLARE Cur_PackInfo CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
   --            SELECT PIF.Pickslipno, PIF.CartonNo    
   --            FROM PACKINFO PIF (NOLOCK)    
   --            WHERE PIF.Pickslipno = @c_Pickslipno    
   --            AND PIF.CartonNo = @n_GetCartonNo --WL02    
   --            --AND PIF.Qty = 0          --WL02    
   --            --AND PIF.[Cube] = 0       --WL02    
   --            --AND PIF.[Weight] = 0     --WL02    
   --            AND PIF.CartonGID <> ''    
   --            ORDER BY PIF.CartonNo ASC    
    
   --            OPEN Cur_PackInfo    
    
   --            FETCH NEXT FROM Cur_PackInfo INTO @c_Pickslipno, @n_CartonNo    
    
   --            WHILE @@FETCH_STATUS <> -1    
   --            BEGIN    
   --               UPDATE PACKINFO    
   --               SET Qty        =  PD.Qty,    
   --                   CartonType =  CASE WHEN @c_DefaultPackInfo = '1' THEN ISNULL(cz.CartonType,'') ELSE PACKINFO.CartonType END,  --WL02  
   --                   [Cube]     =  CASE WHEN @c_DefaultPackInfo = '1' THEN     
   --                                 CASE WHEN ISNULL(CZ.[Cube],0) = 0 THEN PD.QtyxStdCube ELSE ISNULL(CZ.[Cube],0) END     
   --                                 ELSE PACKINFO.[Cube] END,  --WL02    
   --                   [Weight]   =  CASE WHEN @c_DefaultPackInfo = '1' THEN PD.QtyxStdGrossWgt + ISNULL(CZ.CartonWeight,0) ELSE PACKINFO.[Weight] END  --WL02    
   --               FROM PACKDETAIL (NOLOCK)    
   --               JOIN STORER (NOLOCK) ON (PACKDETAIL.StorerKey = STORER.StorerKey)    
   --               JOIN SKU (NOLOCK) ON (PACKDETAIL.Storerkey = SKU.Storerkey AND PACKDETAIL.SKU = SKU.Sku)    
   --               LEFT JOIN CARTONIZATION CZ (NOLOCK) ON (STORER.CartonGroup = CZ.CartonizationGroup AND CZ.UseSequence = 1)    
   --               JOIN ( SELECT PACKDETAIL.PickslipNo, PACKDETAIL.CartonNo, SUM(Packdetail.Qty) as Qty, SUM(Packdetail.Qty * Sku.StdCube) as QtyxStdCube,    
   --                      SUM(Packdetail.Qty * Sku.StdGrossWgt) as QtyxStdGrossWgt    
   --                      FROM PACKDETAIL (NOLOCK)    
   --                      JOIN SKU (NOLOCK) ON (PACKDETAIL.Storerkey = SKU.Storerkey AND PACKDETAIL.SKU = SKU.Sku)    
   --                      WHERE PACKDETAIL.PickSlipNo = @c_Pickslipno AND PACKDETAIL.CartonNo = @n_CartonNo    
   --                      GROUP BY PACKDETAIL.PickslipNo, PACKDETAIL.CartonNo ) PD     
   --                      ON PD.Pickslipno = PACKDETAIL.PickSlipNo AND PD.CartonNo = PACKDETAIL.CartonNo     
   --               WHERE PACKINFO.PickSlipNo = @c_Pickslipno AND PACKINFO.CartonNo = @n_CartonNo    
   --               AND   PACKDETAIL.PickSlipNo = @c_Pickslipno AND PACKDETAIL.CartonNo = @n_CartonNo      --(Wan01)  
   
   --               SELECT @n_Err = @@ERROR    
    
   --               IF @@ERROR <> 0    
   --               BEGIN    
   --                  SET @n_continue = 3      
   --                  SET @n_err = 60085      
   --                  SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update PackInfo table FAILED. (isp_CreatePackInfo)'       
   --                        + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '       
   --                  GOTO QUIT      
   --               END    
    
   --               FETCH NEXT FROM Cur_PackInfo INTO @c_Pickslipno, @n_CartonNo    
   --            END    
   --            CLOSE Cur_PackInfo    
   --            DEALLOCATE Cur_PackInfo    
   --         END -- If Exists    
   --         FETCH NEXT FROM Cur_PackDetail INTO @c_Pickslipno, @n_GetCartonNo    
   --      END    
   --      CLOSE Cur_PackDetail    
   --      DEALLOCATE Cur_PackDetail    
      
   --   END --END PackCartonGID    
   --END -- Continue    
         
QUIT:    
   IF CURSOR_STATUS( 'LOCAL', 'Cur_PackInfo') in (0 , 1)        
   BEGIN      
      CLOSE Cur_PackInfo      
      DEALLOCATE Cur_PackInfo      
   END      
    
   IF CURSOR_STATUS( 'LOCAL', 'Cur_PackDetail') in (0 , 1)        
   BEGIN      
      CLOSE Cur_PackDetail      
      DEALLOCATE Cur_PackDetail      
   END    
    
   IF @n_Continue=3  -- Error Occured - Process And Return      
   BEGIN      
      SET @b_Success = 0      
      IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt      
      BEGIN      
         ROLLBACK TRAN      
      END      
      ELSE      
      BEGIN      
         WHILE @@TRANCOUNT > @n_StartTCnt      
         BEGIN      
            COMMIT TRAN      
         END      
      END      
      
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_CreatePackInfo'      
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012      
   END      
   ELSE      
   BEGIN      
      SET @b_Success = 1      
      WHILE @@TRANCOUNT > @n_StartTCnt      
      BEGIN      
      COMMIT TRAN      
      END      
   END      
        
   WHILE @@TRANCOUNT < @n_StartTCnt       
      BEGIN TRAN;         
    
    
END -- End Procedure  

GO