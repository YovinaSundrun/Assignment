-- Question 3
CREATE PROCEDURE DataFromXXBCM_ORDER_MGT
AS
BEGIN 

    --INSERT INTO SUPPLIER TABLE
    INSERT INTO Supplier (Supplier_Name, Contact_Name, Supplier_Address, Contact_Number, Email)
        SELECT
            SUPPLIER_NAME, SUPP_CONTACT_NAME, SUPP_ADDRESS, SUPP_CONTACT_NUMBER, SUPP_EMAIL
        FROM
            XXBCM_ORDER_MGT;

    --INSERT INTO ORDERS TABLE
    INSERT INTO Orders (Order_Ref, Order_Date, Supplier_ID, Total_Amount, Order_Description, Order_Status)
        SELECT
            ORDER_REF, PARSE(ORDER_DATE AS date USING 'AR-LB'), SCOPE_IDENTITY(), ORDER_LINE_AMOUNT, ORDER_DESCRIPTION, ORDER_STATUS
        FROM
            XXBCM_ORDER_MGT;

    --INSERT INTO ORDER LINE TABLE
    INSERT INTO Order_Line (Order_ID, Line_Amount, Descp)
        SELECT
            o.Order_ID, om.ORDER_LINE_AMOUNT, om.ORDER_DESCRIPTION
        FROM
            XXBCM_ORDER_MGT om
        INNER JOIN
            Orders o ON om.ORDER_REF = o.Order_Ref;

    --INSERT INTO INVOICE TABLE
    INSERT INTO Invoice (Invoice_Ref, Invoice_Date, Order_ID, Invoice_Status, Hold_Reason, Amount, Invoice_Description)
        SELECT
            om.INVOICE_REFERENCE, PARSE(om.INVOICE_DATE AS date USING 'AR-LB'), o.Order_ID, om.INVOICE_STATUS, om.INVOICE_HOLD_REASON, om.INVOICE_AMOUNT, om.INVOICE_DESCRIPTION
        FROM
            XXBCM_ORDER_MGT om
        INNER JOIN
            Orders o ON om.ORDER_REF = o.Order_Ref;

END
GO

EXEC DataFromXXBCM_ORDER_MGT

--Question 4

CREATE PROCEDURE OrderSummary
AS
BEGIN
    SELECT
        SUBSTRING(ORDER_REF, 3, LEN(ORDER_REF)) AS Order_Reference,
        FORMAT(CONVERT(DATETIME, ORDER_DATE), 'MMM-yyyy') AS Order_Period,
        CONCAT(UPPER(LEFT(SUPPLIER_NAME, 1)), LOWER(SUBSTRING(SUPPLIER_NAME, 2, LEN(SUPPLIER_NAME)))) AS Supplier_Name,
        FORMAT(CONVERT(NUMERIC(18, 2), ORDER_TOTAL_AMOUNT), 'N', 'en-us') AS Order_Total_Amount,
        ORDER_STATUS,
        STUFF((SELECT DISTINCT ', ' + INVOICE_REFERENCE
               FROM XXBCM_ORDER_MGT om
               WHERE om.ORDER_REF = m.ORDER_REF
               FOR XML PATH('')), 1, 2, '') AS Invoice_Reference,
        FORMAT(SUM(CONVERT(NUMERIC(18, 2), INVOICE_AMOUNT)), 'N', 'en-us') AS Invoice_Total_Amount,
        CASE
            WHEN SUM(CASE WHEN INVOICE_STATUS = 'Paid' THEN 1 ELSE 0 END) = COUNT(*) THEN 'OK'
            WHEN SUM(CASE WHEN INVOICE_STATUS = 'Pending' THEN 1 ELSE 0 END) > 0 THEN 'To Follow up'
            ELSE 'To Verify'
        END AS Action
    FROM 
        XXBCM_ORDER_MGT m
    GROUP BY
        ORDER_REF,
        ORDER_DATE,  
        SUPPLIER_NAME,
        ORDER_TOTAL_AMOUNT,
        ORDER_STATUS
    ORDER BY
        ORDER_DATE DESC;
END

EXEC OrderSummary

--Question 5
CREATE PROCEDURE SecondHighestOrderDetails
AS
BEGIN
    SELECT 
        SUBSTRING(ORDER_REF, 3, LEN(ORDER_REF)) AS Order_Reference,
        CONVERT(VARCHAR, ORDER_DATE, 107) AS Order_Date,
        UPPER(SUPPLIER_NAME) AS Supplier_Name,
        FORMAT(CONVERT(NUMERIC(18, 2), ORDER_TOTAL_AMOUNT), 'N', 'en-us') AS Order_Total_Amount,
        ORDER_STATUS,
        STUFF((SELECT '|' + INVOICE_REFERENCE
               FROM XXBCM_ORDER_MGT om
               WHERE om.ORDER_REF = m.ORDER_REF
               FOR XML PATH('')), 1, 1, '') AS Invoice_References
    FROM 
        XXBCM_ORDER_MGT m
    WHERE 
        ORDER_TOTAL_AMOUNT = (
            SELECT 
                MAX(ORDER_TOTAL_AMOUNT)
            FROM 
                XXBCM_ORDER_MGT
            WHERE 
                ORDER_TOTAL_AMOUNT < (
                    SELECT 
                        MAX(ORDER_TOTAL_AMOUNT)
                    FROM 
                        XXBCM_ORDER_MGT
                )
        )
    GROUP BY 
        ORDER_REF,
        ORDER_DATE,
        SUPPLIER_NAME,
        ORDER_TOTAL_AMOUNT,
        ORDER_STATUS;
END
GO
EXEC SecondHighestOrderDetails

--Question 6

CREATE PROCEDURE SupplierOrderSummary
AS
BEGIN
    SELECT 
        s.Supplier_Name,
        s.Contact_Name AS Supplier_Contact_Name,
        CASE
            WHEN CHARINDEX(',', s.Contact_Number) = 7 THEN CONCAT(
                SUBSTRING(s.Contact_Number, 1, 3),
                '-',
                SUBSTRING(s.Contact_Number, 5, 4)
            )
            ELSE s.Contact_Number
        END AS Supplier_Contact_No_1,
        CASE
            WHEN CHARINDEX(',', s.Contact_Number) = 7 THEN CONCAT(
                SUBSTRING(s.Contact_Number, 9, 3),
                '-',
                SUBSTRING(s.Contact_Number, 13, 4)
            )
            ELSE SUBSTRING(s.Contact_Number, 9, LEN(s.Contact_Number))
        END AS Supplier_Contact_No_2,
        COUNT(o.Order_ID) AS Total_Orders,
        FORMAT(SUM(CAST(o.Total_Amount AS INT)), 'N', 'en-us') AS Order_Total_Amount
    FROM 
        Supplier s
    INNER JOIN 
        Orders o ON s.Supplier_ID = o.Supplier_ID
    WHERE 
        o.Order_Date BETWEEN '2022-01-01' AND '2022-08-31'
    GROUP BY 
        s.Supplier_ID, 
        s.Supplier_Name,
        s.Contact_Name,
        s.Contact_Number;
END

EXEC SupplierOrderSummary

