SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure:  isp_UCC_Carton_Label_41_2                          */
/* Creation Date: 7-Mar-2016                                            */
/* Copyright: IDS                                                       */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose:  To print Ucc Carton Label 40 (Wholesale Content)           */
/*                                                                      */
/* Input Parameters: Storerkey ,PickSlipNo, CartonNoStart, CartonNoEnd  */
/*                                                                      */
/* Output Parameters:                                                   */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Called By:  r_dw_ucc_carton_label_41                                */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 09-MAY-2016  CSCHONG  1.0  Add field (CS01)                          */
/* 12-May-2016  CSCHONG  1.1. fix loc blank issue (CS02)                */
/* 11-JUL-2016  CSCHONG  1.2  Set Maxline to 15 (CS03)                  */
/* 25-JUL-2016  CSCHONG  1.3  Change loc mapping (CS04)                 */
/* 18-Jul-2016  MTTey    1.3  IN00090573 Revised ODETUserDef04  to 18   */
/*                            character and n_MaxLineno to 19 (MT01)    */
/* 11-Aug-2016  CSCHONG  1.4  SOS#373800-Add new field and sorting (CS05)*/
/* 04-Oct-2016  SPChin   1.5  IN00152476 - Add Filter By LabelNo        */
/* 19-Oct-2016  TLTING   1.6  Performance tune                          */
/* 21-DEC-2018  WLCHOOI  1.7  WMS-7319 - add new field (WL01)           */
/* 20-Mar-2019  TLTING   1.8  missing nolock                            */
/* 20-MAR-2019  CSCHONG  1.9  WMS-8273 - revised field logic (CS06)     */
/************************************************************************/

CREATE PROC [dbo].[isp_UCC_Carton_Label_41_2] (
         @c_StorerKey      NVARCHAR(20)
      ,  @c_PickSlipNo     NVARCHAR(20)
      ,  @c_StartCartonNo  NVARCHAR(20)
      ,  @c_EndCartonNo    NVARCHAR(20)
)
AS
BEGIN

   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF


   DECLARE @c_ExternOrderkey  NVARCHAR(150)
         , @c_GetExtOrdkey    NVARCHAR(150)
         , @c_GrpExtOrderkey  NVARCHAR(150)
         , @c_OrdUserDef09    NVARCHAR(20)
         , @c_OrdUserDef02    NVARCHAR(20)
         , @c_OrdBuyerPO      NVARCHAR(20)
         , @n_cartonno        INT
         , @c_PDLabelNo       NVARCHAR(20)
         , @c_PIDLOC          NVARCHAR(10)
         , @c_SKU             NVARCHAR(20)
         , @c_putawayzone     NVARCHAR(10)
         , @c_PICtnType       NVARCHAR(10)
         , @n_PDqty           INT
         , @c_MixSku          NVARCHAR(1)
         , @c_Orderkey        NVARCHAR(20)
         , @c_Delimiter       NVARCHAR(1)
         , @n_lineNo          INT
         , @c_Prefix          NVARCHAR(3)
         , @n_CntOrderkey     INT
         , @c_SKUStyle        NVARCHAR(100)
         , @n_CntSize         INT
		 , @n_Page            INT
		 , @c_ordkey          NVARCHAR(20)
		 , @n_PrnQty          INT
		 , @c_picloc          NVARCHAR(10)
		 , @c_getpicloc       NVARCHAR(10)
		 , @n_MaxId       INT
		 , @n_MaxRec          INT
		 , @n_getPageno       INT
		 , @n_MaxLineno       INT
		 , @n_CurrentRec      INT
		 , @n_qty             INT           --(CS01)
		 , @c_GetPDLabelNo    NVARCHAR(20)  --(CS02)
		 , @c_GetPIDLOC       NVARCHAR(10)  --(CS02)
		 , @c_getsku         NVARCHAR(20)   --(CS02)
		 , @c_CARTERPO        NVARCHAR(10)   --(CS05)
		 , @c_ShowVAS         NVARCHAR(1)    --(WL01)
		 , @c_OHUDF09         NVARCHAR(50)   --(CS06)

   SET @c_ExternOrderkey  = ''
   SET @c_GetExtOrdkey    = ''
   SET @c_OrdUserDef09    = ''
   SET @c_OrdUserDef02    = ''
   SET @c_OrdBuyerPO      = ''
   SET @n_cartonno        = 1
   SET @c_PDLabelNo       = ''
   SET @c_PIDLOC          = ''
   SET @c_SKU             = ''
   SET @c_putawayzone     = ''
   SET @c_PICtnType       = ''
   SET @c_MixSku          = 'N'
   SET @n_PDqty           = 0
   SET @c_Orderkey        = ''
   SET @c_Delimiter       = ','
   SET @n_lineNo          =1
   SET @c_Prefix          ='Ext'
   SET @n_CntOrderkey     = 1
   SET @c_SKUStyle        = ''
   SET @n_CntSize         = 1
   SET @c_GrpExtOrderkey = ''
	SET @n_Page            = 1
	SET @n_PrnQty          = 1
	SET @c_picloc          = ''
	SET @c_getpicloc       = ''
	SET @n_MaxLineno       = 17         --(CS03)
	SET @n_qty             = 0          --(CS01)
	SET @c_CARTERPO        = ''         --(CS05)
	SET @c_ShowVAS         = ''         --(WL01)

  CREATE TABLE #TMP_WSCartonLABEL (
          rowid           int identity(1,1),
          Pickslipno      NVARCHAR(20) NULL,
          OrdUserDef09    NVARCHAR(20) NULL,
          OrdUserDef02    NVARCHAR(20) NULL,
          OrdExtOrdKey    NVARCHAR(150) NULL,
          OrdBuyerPO      NVARCHAR(20) NULL,
          PDLabelNo       NVARCHAR(20) NULL,
          PIDLOC          NVARCHAR(10) NULL,
          ODETUserDef04   NVARCHAR(18) NULL,
          SKUStyle        NVARCHAR(100) NULL,
          ORDUpSource     NVARCHAR(10) NULL,
          PDQty           INT,
          PICtnType       NVARCHAR(10) NULL,
          OBG             NVARCHAR(3) NULL,
          MixSku          NVARCHAR(1) DEFAULT'N',
          PageNo          INT,
          sku             NVARCHAR(20),
          Slot            NVARCHAR(50),
          Qty             INT NULL,            --(CS01)
          CARTERPO        NVARCHAR(10) NULL,             --(CS05)
		  showvas         NVARCHAR(1)  NULL)             --(WL01)

			 CREATE TABLE #TMP_WSCartonLABEL_1 (
          rowid           int identity(1,1),
          Pickslipno      NVARCHAR(20) NULL,
          OrdUserDef09    NVARCHAR(20) NULL,
          OrdUserDef02    NVARCHAR(20) NULL,
          OrdExtOrdKey    NVARCHAR(150) NULL,
          OrdBuyerPO      NVARCHAR(20) NULL,
          PDLabelNo       NVARCHAR(20) NULL,
          PIDLOC          NVARCHAR(10) NULL,
          ODETUserDef04   NVARCHAR(18) NULL,
          SKUStyle        NVARCHAR(100) NULL,
          ORDUpSource     NVARCHAR(10) NULL,
          PDQty           INT NULL,
          PICtnType       NVARCHAR(10) NULL,
          OBG             NVARCHAR(3) NULL,
          MixSku          NVARCHAR(1) DEFAULT'N',
          PageNo          INT,
          sku             NVARCHAR(20),
          Slot            NVARCHAR(50),
          recgroup        INT NULL,
          Qty             INT NULL,               --(CS01)
		  CARTERPO        NVARCHAR(10) NULL,             --(CS05)
		  showvas         NVARCHAR(1)  NULL)             --(WL01)

   INSERT INTO #TMP_WSCartonLABEL(Pickslipno,OrdUserDef09,OrdUserDef02,OrdExtOrdKey,OrdBuyerPO,PDLabelNo,
               PIDLOC,ODETUserDef04,SKUStyle,ORDUpSource,PDQty,PICtnType,OBG,MixSku,Pageno,sku,slot,qty,CARTERPO,showvas  )   --(CS05)  --(WL01)s
   SELECT   DISTINCT PAH.Pickslipno
         ,  ISNULL(RTRIM(ORDERS.Userdefine09),'')
         ,  ISNULL(RTRIM(ORDERS.Userdefine02),'')
         ,  ''--ISNULL(RTRIM(ORDERS.ExternOrderkey),'')
         ,  ISNULL(RTRIM(ORDERS.BuyerPO),'')               
         ,  ISNULL(RTRIM(PADET.Labelno),'')
        -- ,  ISNULL(RTRIM(PIDET.Loc),'')
		   ,''--,  CASE WHEN ISNULL(TD.FinalLOC,'') = '' THEN TD.ToLoc ELSE TD.FinalLOC END --(CS02)
         ,  ISNULL(RTRIM(ORDDET.Userdefine04),'')
         ,  ISNULL(RTRIM(S.Style),'') + ' ' + ISNULL(RTRIM(S.color),'') + ' ' + ISNULL(RTRIM(S.Measurement),'') + ' ' + ISNULL(RTRIM(S.Size),'')
         ,  ISNULL(RTRIM(ORDERS.UpdateSource),'')
         ,0
         ,ISNULL(PAIF.CartonType,'')
         ,CASE WHEN ORDERS.Door = '002' THEN 'OBG' Else '' END
         ,'N'
			,@n_Page
			,PIDET.SKU
			,CL.Short
			,0
			, ''        --(CS05)
			, ''        --(WL01)
   FROM PACKHEADER PAH WITH (NOLOCK)
   JOIN PACKDETAIL PADET WITH (NOLOCK) ON PAH.Pickslipno = PADET.Pickslipno
   JOIN PICKDETAIL PIDET WITH (NOLOCK) ON PIDET.CaseId = PADET.Labelno
	                                    AND PIDET.SKU = PADET.SKU
    JOIN ORDERDETAIL ORDDET WITH (NOLOCK) ON ORDDET.Orderkey = PIDET.Orderkey
                                          AND ORDDET.Orderlinenumber=PIDET.Orderlinenumber
   JOIN ORDERS     WITH (NOLOCK) ON (ORDDET.Orderkey = ORDERS.Orderkey)
   JOIN SKU S WITH (NOLOCK) ON S.Storerkey = PADET.Storerkey and S.SKU = PADET.SKU
   LEFT JOIN PACKINFO  PAIF WITH (NOLOCK) ON PAIF.Pickslipno =PADET.Pickslipno AND PAIF.CartonNo = PADET.CartonNo
	--LEFT JOIN Taskdetail TD WITH (NOLOCK) ON TD.TaskDetailKey=PIDET.TaskDetailKey                                  --(CS02)
	--                                 AND TD.TaskType='RPF'                                                         --(CS02)
   --JOIN WAVEDETAIL WDET WITH (NOLOCK) ON WDET.Orderkey = ORDERS.Orderkey
	JOIN WAVE WV WITH (NOLOCK) ON WV.Wavekey = PIDET.WaveKey
	LEFT JOIN CODELKUP CL WITH (NOLOCK) ON CL.listname='DICSEPKMTD' AND CL.code=WV.DispatchCasePickMethod
   WHERE PAH.Pickslipno = @c_PickSlipNo
   AND   PAH.Storerkey = @c_StorerKey
   AND PADET.CartonNo between CONVERT(INT,@c_StartCartonNo) AND CONVERT(INT,@c_EndCartonNo)
   ORDER BY ISNULL(RTRIM(PADET.Labelno),'')


   /*CS02 Start*/


   DECLARE CUR_PDLOC CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT
          PDLabelNo,sku
   FROM #TMP_WSCartonLABEL WITH (NOLOCK)
   WHERE Pickslipno = @c_PickSlipNo

   OPEN CUR_PDLOC

   FETCH NEXT FROM CUR_PDLOC INTO @c_GetPDLabelNo,@c_getsku


   WHILE @@FETCH_STATUS <> -1
   BEGIN


      SET @c_GetPIDLOC = ''

		--SELECT TOP 1 @c_GetPIDLOC = CASE WHEN ISNULL(TD.FinalLOC,'') = '' THEN TD.ToLoc ELSE TD.FinalLOC END   --(CS04)
		SELECT TOP 1 @c_GetPIDLOC = CASE WHEN ISNULL(TD.logicaltoloc,'') = '' THEN TD.ToLoc ELSE TD.logicaltoloc END   --(CS04)
		FROM PICKDETAIL PD WITH (NOLOCK)
		LEFT JOIN TaskDetail AS TD WITH (NOLOCK) ON TD.TaskDetailKey=PD.TaskDetailKey
		WHERE  TD.TaskType='RPF'
		AND pd.CaseID=@c_GetPDLabelNo
		AND pd.sku=@c_getsku


		UPDATE #TMP_WSCartonLABEL
		SET PIDLOC = @c_GetPIDLOC
		WHERE PDLabelNo = @c_GetPDLabelNo
		AND sku=@c_getsku

	FETCH NEXT FROM CUR_PDLOC INTO @c_GetPDLabelNo,@c_getsku

   END
   CLOSE CUR_PDLOC
   DEALLOCATE CUR_PDLOC

   /*CS02 End*/
  DECLARE CUR_Labelno CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT
          PDLabelNo
        -- ,cartonno
         ,sku
         ,PIDLOC
   FROM #TMP_WSCartonLABEL WITH (NOLOCK)
   WHERE Pickslipno = @c_PickSlipNo

   OPEN CUR_Labelno

   FETCH NEXT FROM CUR_Labelno INTO @c_PDLabelNo
                                    --,@n_cartonno
                                    ,@c_SKU
                                    ,@c_PIDLOC

   WHILE @@FETCH_STATUS <> -1
   BEGIN

	   SET @n_prnqty = 1

      --SELECT @n_CntOrderkey = Count(DISTINCT Orderkey)
      --FROM PACKHEADER PAH WITH (NOLOCK)
      --JOIN PACKDETAIL PADET WITH (NOLOCK) ON PAH.Pickslipno = PADET.Pickslipno
      --WHERE PADET.Labelno = @c_PDLabelNo

      SELECT @n_CntOrderkey = Count(DISTINCT Orderkey)
      FROM PICKDETAIL PIDET WITH (NOLOCK)
      WHERE PIDET.Caseid = @c_PDLabelNo

		SELECT TOP 1 @n_prnqty = billedContainerQTy
		FROM PICKDETAIL PIDET WITH (NOLOCK)
		JOIN ORDERS ORD WITH (NOLOCK) ON ORD.Orderkey = PIDET.Orderkey
		WHERE PIDET.Caseid = @c_PDLabelNo


        IF @n_CntOrderkey <> 0
        BEGIN
           IF @n_CntOrderkey = 1
           BEGIN
            SET @c_Delimiter = ''
           END
        END
        
          /*CS05 start*/
					SELECT @c_OrdBuyerPO = ORD.BuyerPO
					      ,@c_OHUDF09 = ORD.Userdefine09               --CS06 
					FROM PICKDETAIL PIDET WITH (NOLOCK)
					JOIN ORDERS ORD WITH (NOLOCK) ON ORD.Orderkey = PIDET.Orderkey
					WHERE PIDET.Caseid = @c_PDLabelNo
					
					
		IF ISNULL(@c_OrdBuyerPO,'') <> ''
		BEGIN			
		  SELECT @c_CARTERPO = ISNULL(CL.short,'')
			FROM CODELKUP AS CL WITH (NOLOCK)
		  --LEFT JOIN  ( SELECT DISTINCT PD.WaveKey    --CS06 
				--	  FROM PICKDETAIL PD WITH (NOLOCK)
				--	  WHERE PD.Caseid = @c_PDLabelNo ) AS A ON A.WaveKey=CL.CODE
					  WHERE CL.LISTNAME='CARTERPO'	
					  AND CL.code2= @c_OrdBuyerPO
					  AND CL.code = @c_OHUDF09          --CS06
		END		
			
		/*CS05 End*/	
      --tlting01
		IF EXISTS (SELECT 1 FROM PICKDETAIL PD (NOLOCK) 
               JOIN OrderDetailRef ODR  (NOLOCK) ON ODR.OrderKey = PD.OrderKey 
					AND ODR.Storerkey = PD.Storerkey AND PD.OrderLineNumber=ODR.OrderLineNumber
					WHERE PD.CaseID=@c_GetPDLabelNo AND ODR.RetailSKU IN 
					(SELECT Code FROM Codelkup  (NOLOCK) 
               WHERE ListName='CARTERVAS' AND StorerKey=@c_StorerKey AND Short='Y'))
		BEGIN
			SET @c_showvas = 'Y'
		END

        IF ISNULL(@c_PIDLOC,'') = ''
        BEGIN
			  SELECT TOP 1 @c_getpicloc=LLD.loc
			  FROM lotxlocxid LLD (NOLOCK)
			  JOIN LOC L (NOLOCK) ON L.Loc = LLd.LOC
			  where LLD.sku=@c_sku AND L.LocationCategory='SHELVING'
			  AND L.LocationType='DYNPPICK' AND LLD.qty>0

        END
        ELSE
        BEGIN
          SET @c_getpicloc = @c_PIDLOC
        END

        SET @c_ExternOrderkey = ''

        DECLARE CUR_ExtnOrdKey CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
        SELECT DISTINCT ExternOrderkey
        FROM PICKDETAIL PIDET WITH (NOLOCK)
        JOIN ORDERS ORD WITH (NOLOCK) ON ORD.Orderkey = PIDET.Orderkey
        WHERE PIDET.caseid = @c_PDLabelNo
        ORDER BY 1

        OPEN CUR_ExtnOrdKey

        FETCH NEXT FROM CUR_ExtnOrdKey INTO @c_ExternOrderkey

        WHILE @@FETCH_STATUS <> -1
        BEGIN

        --SET @c_ExternOrderkey = @c_Prefix + RIGHT('000'+CAST(ISNULL(@n_lineNo,'000') as nvarchar(3)),3) + @c_Delimiter

        SET @c_GrpExtOrderkey = @c_ExternOrderkey + @c_Delimiter

        SET @c_GetExtOrdkey = @c_GetExtOrdkey + @c_GrpExtOrderkey

        --SET @n_lineNo = @n_lineNo + 1
       -- SET @n_CntOrderkey = @n_CntOrderkey - 1


        FETCH NEXT FROM CUR_ExtnOrdKey INTO @c_ExternOrderkey
        END

        CLOSE CUR_ExtnOrdKey
        DEALLOCATE CUR_ExtnOrdKey

        SELECT @n_CntSize = Count(size)
        FROM SKU (NOLOCK)
        WHERE storerkey = @c_storerkey
        AND sku = @c_SKU

        SELECT @n_PDqty = SUM(qty)
              ,@n_qty  = SUM(qty*s.busr1)         --(CS01)
        FROM PACKDETAIL PD WITH (NOLOCK)
        JOIN SKU S WITH (NOLOCK) ON S.SKU = PD.Sku
        WHERE PD.labelno = @c_PDLabelNo
        AND S.sku = @c_SKU
        AND S.storerkey = @c_storerkey

        IF @n_CntSize > 1
         BEGIN
           SET @c_MixSku = 'Y'
         END

         UPDATE #TMP_WSCartonLABEL
         SET OrdExtOrdKey = @c_GetExtOrdkey
            ,PDQty  = @n_PDqty
            , MixSku= @c_MixSku
            , PIDLOC = @c_getpicloc
            , Qty    = @n_qty                            --(CS01)
            , CARTERPO = ISNULL(@c_CARTERPO,'')             --(CS05)
			, showvas = @c_ShowVAS                        --(WL01)
         WHERE PDLabelNo = @c_PDLabelNo
         --AND cartonno = @n_cartonno
         AND SKU = @c_SKU

   SET @c_GetExtOrdkey = ''
   SET @n_lineNo = 1
   FETCH NEXT FROM CUR_Labelno INTO @c_PDLabelNo
                                   -- ,@n_cartonno
                                    ,@c_SKU
                                    ,@c_PIDLOC
   END
   CLOSE CUR_Labelno
   DEALLOCATE CUR_Labelno

	WHILE @n_prnqty > 1
	BEGIN

		INSERT INTO #TMP_WSCartonLABEL
		( Pickslipno,OrdUserDef09,OrdUserDef02,OrdExtOrdKey,OrdBuyerPO,PDLabelNo,
          PIDLOC,ODETUserDef04,SKUStyle,ORDUpSource,PDQty,PICtnType,OBG,MixSku,Pageno,sku,slot,qty,CARTERPO             --(CS01) --(CS05)
		  ,showvas)      --(WL01)
		 SELECT Pickslipno,OrdUserDef09,OrdUserDef02,OrdExtOrdKey,OrdBuyerPO,PDLabelNo,
          PIDLOC,ODETUserDef04,SKUStyle,ORDUpSource,PDQty,PICtnType,OBG,MixSku,(@n_Page+1),sku,slot,qty ,CARTERPO        --(CS01) --(CS05)
		  ,showvas      --(WL01)
		 FROM #TMP_WSCartonLABEL
		 WHERE pageno = @n_Page

		SET @n_prnqty = @n_prnqty - 1
		SET @n_Page = @n_Page + 1
	END


   IF @n_prnqty >= 1
	BEGIN
		INSERT INTO #TMP_WSCartonLABEL_1
		( Pickslipno,OrdUserDef09,OrdUserDef02,OrdExtOrdKey,OrdBuyerPO,PDLabelNo,
          PIDLOC,ODETUserDef04,SKUStyle,ORDUpSource,PDQty,PICtnType,OBG,MixSku,Pageno,sku,slot,recgroup,qty,CARTERPO   --(CS01)  --(CS05)
		  ,showvas)      --(WL01)
	SELECT Pickslipno ,OrdUserDef09,OrdUserDef02,OrdExtOrdKey,OrdBuyerPO,PDLabelNo,
				 PIDLOC,ODETUserDef04,SKUStyle,ORDUpSource,SUM(PDQty) AS PDQty,PICtnType,OBG,MixSku,Pageno,'',slot
				 ,(Row_Number() OVER (PARTITION BY Pickslipno ORDER BY PIDLOC Asc)-1)/@n_MaxLineno+1 AS recgroup
				 , SUM(Qty) AS Qty  ,CARTERPO                                                                                 --(CS01)  --(CS05)
				 ,showvas      --(WL01)
		--INTO #TMP_WSCartonLABEL_2
		FROM #TMP_WSCartonLABEL WITH (NOLOCK)
		GROUP BY Pickslipno,OrdUserDef09,OrdUserDef02,OrdExtOrdKey,OrdBuyerPO,PDLabelNo,
				 PIDLOC,ODETUserDef04,SKUStyle,ORDUpSource,PICtnType,OBG,MixSku,Pageno,slot,CARTERPO                        --(CS05)
				 ,showvas      --(WL01)
	ORDER BY PIDLOC                                                                                                      --(CS05)		 


	DECLARE CUR_PageLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT pageno
      FROM   #TMP_WSCartonLABEL_1
      ORDER BY pageno

      OPEN CUR_PageLoop

      FETCH NEXT FROM CUR_PageLoop INTO @n_GetPageno

      WHILE @@FETCH_STATUS <> -1
      BEGIN

      SELECT @n_MaxRec = MAX(recgroup)
            ,@n_MaxId  = MAX(rowid)
      FROM  #TMP_WSCartonLABEL_1
      WHERE PageNo = @n_GetPageno

      SET @n_CurrentRec =  @n_MaxId%@n_MaxLineno

       WHILE @n_MaxId%@n_MaxLineno <> 0 AND @n_CurrentRec < @n_MaxLineno
       BEGIN
       	INSERT INTO #TMP_WSCartonLABEL_1
		   ( Pickslipno,OrdUserDef09,OrdUserDef02,OrdExtOrdKey,OrdBuyerPO,PDLabelNo,
          ORDUpSource,PICtnType,OBG,MixSku,Pageno,sku,slot,recgroup,CARTERPO                       --(CS05)
		  ,showvas)      --(WL01)
         SELECT TOP 1 Pickslipno,OrdUserDef09,OrdUserDef02,OrdExtOrdKey,OrdBuyerPO,PDLabelNo,
          ORDUpSource,PICtnType,OBG,MixSku,Pageno,sku,slot,recgroup,CARTERPO                         --(CS05)
		  ,showvas      --(WL01)
         FROM #TMP_WSCartonLABEL_1
         WHERE PageNo = @n_GetPageno
         AND recgroup = @n_MaxRec

         SET @n_CurrentRec = @n_CurrentRec + 1
       END

       FETCH NEXT FROM CUR_PageLoop INTO @n_GetPageno
       END

       CLOSE CUR_PageLoop

	SELECT Pickslipno,OrdUserDef09,OrdUserDef02,OrdExtOrdKey,OrdBuyerPO,PDLabelNo,
          PIDLOC,ODETUserDef04,SKUStyle,ORDUpSource,PDQty,PICtnType,OBG,MixSku,Pageno,slot,recgroup,qty,CARTERPO   --(CS05)
		  ,showvas      --(WL01)
	FROM #TMP_WSCartonLABEL_1
	ORDER BY CASE WHEN ISNULL(PIDLOC,'') = '' THEN 1 ELSE 0 END             --(CS05)
	
   END
END

GO